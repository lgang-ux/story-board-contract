// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;

import {StroyNft} from "./nft/StroyNft.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
 * nft工厂
 */
contract StroyNftFactory is Ownable {

    event mintMultipleEvent(address _nftAddress,address _to,uint256[] _tokenIds,string[] uris);

   //创建订单号=> nft 合约地址
    mapping(string=>address) orderNftMap;
   //创建者=> nft 合约地址
   mapping(address=>address) createNftMap;
    //创建nft合约
   function createNft(string memory createNo,string memory name_, string memory symbol_,uint price_) public onlyOwner  returns(address) {
      address nftaddres= address(new StroyNft(name_,symbol_,price_));
      orderNftMap[createNo]=nftaddres;
      createNftMap[nftaddres]=msg.sender;
      return nftaddres;
    }

     //单个mint
     function safeMint(address nftAddress,address to, uint256 tokenId, string memory uri) public onlyOwner   {
        StroyNft(nftAddress).safeMint(to,tokenId,uri);
     }

     //批量mint
     function safeMintMultiple(address nftAddress,address to, uint256[] memory tokenIds, string[] memory uris) public  onlyOwner {
        StroyNft(nftAddress).safeMintMultiple(to,tokenIds,uris);
        emit mintMultipleEvent(nftAddress,to,tokenIds,uris);
     }
      //转移nft合约权限
      function transferOwnerToCreator(address nftAddress) public  onlyOwner {
        StroyNft(nftAddress).transferOwnership(createNftMap[nftAddress]);
     }

     function getNftOwner(string memory orderNo) public view returns(address) {
      address owner= StroyNft(orderNftMap[orderNo]).owner();
      return owner;
     }

     function getNftAddressBycreateNo(string memory createNo) public view returns(address) {
      return orderNftMap[createNo];
     }

     function getNftAddressByCreator(address createAddress ) public view returns(address) {
      return createNftMap[createAddress];
     }
     
     function balanceOf(address nftAddress,address owner) public view returns(uint)  {
        return  StroyNft(nftAddress).balanceOf(owner);
     }

}