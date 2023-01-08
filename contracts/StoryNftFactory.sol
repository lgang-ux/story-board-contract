// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import {StoryNft} from "./nft/StoryNft.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * nft工厂
 * step1：NFT创建者 支付gas创建NFT合约 - createNFT。
 * step2: 平台自动给他mint铸造NFT。
 * step3: 自动交易挂单，将合约授权给交易合约。限价挂单 和 竞拍挂单
 * step4: 将合约所有权交还给用户 完成整体步骤
 */
contract StoryNftFactory is Ownable {

   
    event createNftEvent(uint id,address _nftAddress,address _wallet,uint _gasPrice);
    event setWalletGasEvent(address _wallet,uint _gas);
    event mintMultipleEvent(address _nftAddress,address _to,uint256[] _tokenIds,string[] uris);
    event boxMintEvent(address _nftAddress,address _from,address _to,uint256 _tokenId,string uri,uint price);
    event transferEvent(address _nftAddress,address _from,address _to,uint256 _tokenId);

   //nft 合约地址 => createAddreess
   mapping(address=>address) contractCreatedMap;
   mapping(address =>bool) contractBoxMintMap;
   mapping(address => mapping(uint256 => bool)) boxMintTokenMap;
   mapping(address =>uint) walletGasMap;

   
   address private txServiceFeeAddress; //交易服务费地址
   uint private tradeFeeRate = 50 ;//交易服务费 5% 1000倍
   address private tradeContractAddress ; //交易合约地址


    //创建nft合约
   function createNft(uint id,string memory name_, string memory symbol_,uint price_) payable public  {
      require(walletGasMap[msg.sender] > 0 ,"Gas does not exist, please republish it.");
      require(walletGasMap[msg.sender] <= msg.value,"gas Insufficient.");
      payable(owner()).transfer(msg.value);  //向owner地址转入gas费用
      address nftaddres= address(new StoryNft(tradeContractAddress,name_,symbol_,price_));
      contractCreatedMap[nftaddres]=msg.sender;
      delete walletGasMap[msg.sender];
      if(price_ > 0){
        contractBoxMintMap[nftaddres] = true;
      }
      emit createNftEvent(id,nftaddres,msg.sender,msg.value);
    }

    //设置gas
    function setWalletGas(address _wallet,uint _newGas)public onlyOwner{
        uint gasBlanceOf = walletGasMap[_wallet];
        walletGasMap[_wallet] = gasBlanceOf + _newGas;
        emit setWalletGasEvent(_wallet,_newGas);
    }

    //清理自身Gas
    function cleanWalletGas(address _wallet) public onlyOwner{
        delete walletGasMap[_wallet] ;
    }

    //获取钱包本次发布铸造需要支付的gas费用
    function getWalletGas(address _wallet) public view returns(uint){
        return walletGasMap[_wallet];
    }

    //单个mint
     function safeMint(address nftAddress,address to, uint256 tokenId, string memory uri) public onlyOwner   {
        StoryNft(nftAddress).safeMint(to,tokenId,uri);
     }

    //批量mint
     function safeMintMultiple(address nftAddress,address to, uint256[] memory tokenIds, string[] memory uris) public  onlyOwner {
        StoryNft(nftAddress).safeMintMultiple(to,tokenIds,uris);
        emit mintMultipleEvent(nftAddress,to,tokenIds,uris);
     }

    //盲盒mint , 铸造的钱转给 创建这个合约的人
    function boxMint(address nftAddress, uint256 tokenId, string memory uri) public  payable {
        require(contractBoxMintMap[nftAddress] == true,"Nft small contract not boxMint.");
        require(contractCreatedMap[nftAddress] != address(0),"Nft small contract address error.");
        require(boxMintTokenMap[nftAddress][tokenId] == false,"TokenId already mint.");
        uint boxMintPrice = StoryNft(nftAddress).getPrice();
        require(boxMintPrice > 0,"Nft BoxMint price has than zero.");
        require(msg.value >= boxMintPrice,"Amount not satisfied");
        StoryNft(nftAddress).safeMint(msg.sender,tokenId,uri);
        uint platformFee = msg.value/1000 * tradeFeeRate; //平台扣点
        uint userAmt =  msg.value - platformFee; //用户收款
        boxMintTokenMap[nftAddress][tokenId] = true;
        payable(contractCreatedMap[nftAddress]).transfer(userAmt);  
        payable(txServiceFeeAddress).transfer(platformFee);  
        emit boxMintEvent(nftAddress, contractCreatedMap[nftAddress] ,msg.sender, tokenId, uri, msg.value);
    }

    //转移
    function transfer(address nftAddress, uint256 tokenId,address to)public {
        require(nftAddress != address(0),"Nft small contract address error.");
        require(to != address(0),"Transfer to address error.");
        require(StoryNft(nftAddress).ownerOf(tokenId) == msg.sender,"TokenId not belong to oneself");
        require(to != msg.sender,"You can't transfer yourself.");
        StoryNft(nftAddress).safeTransferFrom(msg.sender,to,tokenId);
        emit transferEvent(nftAddress,msg.sender,to,tokenId);
        
    }

    function balanceOf(address nftAddress,address owner) public view returns(uint)  {
        return  StoryNft(nftAddress).balanceOf(owner);
     }

    function getContractBoxMint(address nftAddress)public view returns(bool){
        return contractBoxMintMap[nftAddress] ;
    }
    function setTxServiceFeeAddress(address _txServiceFeeAddress) public onlyOwner {
        txServiceFeeAddress = _txServiceFeeAddress;
    }
    
    function setTradeFeeRate(uint _tradeFeeRate) public onlyOwner {
        tradeFeeRate = _tradeFeeRate;
    }

    function setTradeContractAddress(address _address) public onlyOwner {
        tradeContractAddress = _address;
    }
  
 
}