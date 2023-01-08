// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "./interface/IERC721.sol";

interface IStoryDeposit {
    function lockDeposit(address _lockAddress,uint lockAmt) external;
    function getLockDepositBalanceOf(address _owner) external returns(uint);
    function getEffectiveDepositBalanceOf(address _owner) external returns(uint);
    function transferLockDeposit(address _from,address _to,uint deductAmt) external;
    function freeLockDeposit(address _from,uint deductAmt) external;
}
/**
交易模块
 */
contract StoryTread is Ownable {

    event saleOderEvent(address _contractAddress,address _from,uint _tokenId,uint _amt);
    event revokeOderEvent(address _contractAddress,address _from,uint _tokenId);
    event buyEvent(address _contractAddress,address _from,address _to,uint _tokenId,uint sell_amt,uint user_amt,uint platform_amt);
    event biddingSellEvent(address _contractAddress,address _from,uint _tokenId,uint startPrice,uint minAddPrice,uint limitPrice,uint strtDate,uint endDate);
    event offerPriceEvent(address _contractAddress,address _from, uint _tokenId,uint _offerPrice);
    event makeBiddingEvent(address _contractAddress,address _from,address _to,uint _tokenId,uint sell_amt,uint user_amt,uint platform_amt);
    event enquiryEvent(address _contractAddress,address _from,address _to,uint _tokenId,uint price);
    event makeEnquiryEvent(address _contractAddress,address _from,address _to,uint _tokenId,uint sell_amt,uint user_amt,uint platform_amt);
    //contract => tokenId =>price  
    mapping(address =>mapping(uint =>uint)) private contractTokenSaleMap;
    //contract => tokenId => owner  
    mapping(address =>mapping(uint =>address)) private ownerOrderMap;
    //contract => tokenId => biddingOrder 
    mapping(address => mapping(uint => Bidding)) private biddingTokenSaleMap;
     //contract =>tokenId => offer price
    mapping(address =>mapping(uint => Offer[])) private offerMap;
    //contract =>tokenId => max offer price
    mapping(address =>mapping(uint => Offer)) private maxOfferMap;
    //contract => tokenId => boola 限价
    mapping(address => mapping(uint => bool)) private limitBiddingMap;
    //enquirey log
    mapping(address =>mapping(uint => Enquiry[])) private enquiryMap;

    
    address private txServiceFeeAddress; //交易服务费地址

    uint private tradeFeeRate = 50 ;//交易服务费 5% 1000倍
    
    uint private enquiryOutTime = 48 * 60 * 60; 


   struct Bidding {
        address from;
        uint startPrice;//起拍价格
        uint minAddPrice; //最低加价
        uint limitPrice ;//限价
        uint startDate; //开始时间
        uint endDate; //结束时间
   }

   struct Offer {
       address offerAddress;
       uint offerPrice;
   }
   
   struct Enquiry{
    address enquiryAddress;
    uint price;
    uint time; //询价时间
   }
   
    address private storyDepositAddress; //保证金合约
    constructor(address _storyDepositAddress) {
        storyDepositAddress = _storyDepositAddress;
    }

     //挂单
     function sale(address _contractAddress,uint _tokenId, uint _price) public{
        require(IERC721(_contractAddress).isApprovedForAll(msg.sender,address(this)),"NFT does not ApprovedForAll");
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"token does not belong to you.");
        require(contractTokenSaleMap[_contractAddress][_tokenId]  == 0,"NFT already on sale.");
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from == address(0),"Auction order already exists.");
        require(_price > 0,"sell price must than zero.");
        contractTokenSaleMap[_contractAddress][_tokenId] = _price;
        ownerOrderMap[_contractAddress][_tokenId] = msg.sender;
        emit saleOderEvent(_contractAddress,msg.sender,_tokenId,_price);
    }

    //批量挂单
    function saleBatch(address _contractAddress,uint[] memory _tokenIds, uint[] memory _prices) public{
        require(_tokenIds.length > 0,"token is null");
        require(_prices.length > 0,"price is null");
         require(_tokenIds.length == _prices.length ,"token number and price number not match.");
        for(uint idx = 0; idx < _tokenIds.length ; idx++){
            sale(_contractAddress,_tokenIds[idx],_prices[idx]);
        }
    }

    //撤单
    function revoke(address _contractAddress,uint _tokenId) public{
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"token does not belong to you.");
        require(contractTokenSaleMap[_contractAddress][_tokenId] > 0,"NFT sell order does not exist.");
        require(ownerOrderMap[_contractAddress][_tokenId] == msg.sender,"The order does not belong to you.");
        delete contractTokenSaleMap[_contractAddress][_tokenId] ;
        delete ownerOrderMap[_contractAddress][_tokenId] ;
        emit revokeOderEvent(_contractAddress,msg.sender,_tokenId);
    }

    //订单成交
     function buy(address _contractAddress,uint _tokenId) public payable {
        address orderOwner = ownerOrderMap[_contractAddress][_tokenId];
        uint orderPrice = contractTokenSaleMap[_contractAddress][_tokenId];
        require(IERC721(_contractAddress).ownerOf(_tokenId) == orderOwner ,"There is an error in token attribution.");
        require(orderPrice > 0,"NFT sell order does not exist.");
        require(msg.value >= orderPrice,"Insufficient purchase amount.");
        require(orderOwner != msg.sender,"You can't buy yourself.");
        uint platformFee = msg.value/1000 * tradeFeeRate; //平台扣点
        uint userAmt = msg.value - platformFee; //用户收款
        delete contractTokenSaleMap[_contractAddress][_tokenId] ;
        delete ownerOrderMap[_contractAddress][_tokenId] ;
        delete enquiryMap[_contractAddress][_tokenId]; //清理询价记录
        payable(orderOwner).transfer(userAmt); 
        payable(txServiceFeeAddress).transfer(platformFee);
        IERC721(_contractAddress).transferFrom(orderOwner,msg.sender,_tokenId); //转移NFT
        emit buyEvent(_contractAddress,orderOwner,msg.sender,_tokenId,msg.value,userAmt,platformFee);
    }


    /**
        竞拍挂单
        _contractAddress 合约地址
        _tokenId TokenId
        startPrice 起拍价格
        minAddPrice 最小加价
        limitPrice 限价
        startDate 开始时间
        endDate 结束时间
     */
     function biddingSell(address _contractAddress,uint _tokenId, uint startPrice,uint minAddPrice,uint limitPrice,uint strtDate,uint endDate) public{
        require(IERC721(_contractAddress).isApprovedForAll(msg.sender,address(this)),"NFT does not ApprovedForAll");
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"token does not belong to you.");
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from == address(0),"Auction order already exists.");
        require(contractTokenSaleMap[_contractAddress][_tokenId]  == 0,"NFT already on sale.");
        require(startPrice > 0,"The starting price must be greater than 0.");
        require(minAddPrice > 0,"The minimum markup must be greater than 0.");
        require(endDate > block.timestamp,"endDate less than timestamp.");
        biddingTokenSaleMap[_contractAddress][_tokenId] = Bidding(msg.sender,startPrice,minAddPrice,limitPrice,strtDate,endDate);
        emit biddingSellEvent(_contractAddress,msg.sender,_tokenId,startPrice,minAddPrice,limitPrice,strtDate,endDate);
    }

    //撤销订单（未成交 和 没有报价的情况下 用户主动撤销）
    function biddingRevoke(address _contractAddress,uint _tokenId) public {
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"token does not belong to you.");
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from != address(0),"Auction order does not exist.");
        require(maxOfferMap[_contractAddress][_tokenId].offerPrice == 0,"Offer already exists and cannot be revoked");
        delete biddingTokenSaleMap[_contractAddress][_tokenId] ;
        emit revokeOderEvent(_contractAddress, msg.sender,_tokenId);
    }

    //竞拍出价
     function offerPrice(address _contractAddress, uint _tokenId,uint _offerPrice) public{
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from != address(0),"Auction order does not exist.");
        Bidding memory bidding = biddingTokenSaleMap[_contractAddress][_tokenId];
        require(block.timestamp > bidding.startDate,"The auction has not yet started.");
        require(block.timestamp < bidding.endDate,"auction has ended.");
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from != msg.sender,"You can't offer yourself.");
        require(_offerPrice > maxOfferMap[_contractAddress][_tokenId].offerPrice + bidding.minAddPrice,"offer price too small,less than last offer");
        uint depositAmt = IStoryDeposit(storyDepositAddress).getEffectiveDepositBalanceOf(msg.sender);
        require(depositAmt >= _offerPrice,"Insufficient margin available balance.");
        IStoryDeposit(storyDepositAddress).lockDeposit(msg.sender,_offerPrice); //lock deposit
        maxOfferMap[_contractAddress][_tokenId] = Offer(msg.sender,_offerPrice);
        offerMap[_contractAddress][_tokenId].push(Offer(msg.sender,_offerPrice));
        if(bidding.limitPrice != 0  && _offerPrice > bidding.limitPrice){
            limitBiddingMap[_contractAddress][_tokenId] = true;
        }
        emit offerPriceEvent(_contractAddress,msg.sender,_tokenId,_offerPrice);
     }

     
    //竞拍成交 -- 账户自动成交
     function makeBidding(address _contractAddress, uint _tokenId) public onlyOwner{
        require(biddingTokenSaleMap[_contractAddress][_tokenId].from != address(0),"Auction order does not exist.");
        Bidding memory bidding = biddingTokenSaleMap[_contractAddress][_tokenId];
        if(limitBiddingMap[_contractAddress][_tokenId] == false){  //检查是否满足限价成交 - 如果满足则不检查时间
            require(block.timestamp > bidding.endDate,"The auction is not over yet.");
        }
        Offer memory maxOffer = maxOfferMap[_contractAddress][_tokenId];
        require(IStoryDeposit(storyDepositAddress).getLockDepositBalanceOf(maxOffer.offerAddress) >= maxOffer.offerPrice,"Insufficient lock-up margin, unable to trade.");
        uint platformFee = maxOffer.offerPrice/1000 * tradeFeeRate; //平台扣点
        uint userAmt =  maxOffer.offerPrice - platformFee; //用户收款
        delete biddingTokenSaleMap[_contractAddress][_tokenId]; 
        delete maxOfferMap[_contractAddress][_tokenId];
        delete limitBiddingMap[_contractAddress][_tokenId];
        IERC721(_contractAddress).transferFrom(bidding.from,maxOffer.offerAddress,_tokenId); //转移NFT
        IStoryDeposit(storyDepositAddress).transferLockDeposit(maxOffer.offerAddress,bidding.from,userAmt);
        IStoryDeposit(storyDepositAddress).transferLockDeposit(maxOffer.offerAddress,txServiceFeeAddress,platformFee);
        Offer[] memory offers = offerMap[_contractAddress][_tokenId];
        for(uint256 idx  = 0; idx < offers.length ; idx++ ){   //解除其他出价用户保证金
            Offer memory offer = offers[idx];
            if(offer.offerAddress != maxOffer.offerAddress && IStoryDeposit(storyDepositAddress).getLockDepositBalanceOf(offer.offerAddress) >= offer.offerPrice){ //防止释放错误 导致成交失败.
                IStoryDeposit(storyDepositAddress).freeLockDeposit(offer.offerAddress,offer.offerPrice);
                 delete offerMap[_contractAddress][_tokenId][idx];
            }
        }
        delete offerMap[_contractAddress][_tokenId];
        emit makeBiddingEvent(_contractAddress,bidding.from,maxOffer.offerAddress,_tokenId,maxOffer.offerPrice,userAmt,platformFee);
     }

    /**
     * 询价
     */
    function enquiry(address _contractAddress,uint _tokenId,uint price)public {
         require(contractTokenSaleMap[_contractAddress][_tokenId]  > 0 ,"NFT not sale.");
         address owner = IERC721(_contractAddress).ownerOf(_tokenId);
         uint depositAmt = IStoryDeposit(storyDepositAddress).getEffectiveDepositBalanceOf(msg.sender);
         require(depositAmt >= price,"Insufficient available margin." );
         require(owner != msg.sender,"You can't enquiry yourself.");
         IStoryDeposit(storyDepositAddress).lockDeposit(msg.sender,price); //lock deposit
         enquiryMap[_contractAddress][_tokenId].push(Enquiry(msg.sender,price,block.timestamp));
         emit enquiryEvent(_contractAddress,owner,msg.sender,_tokenId,price);
    }

    //询价成交
    function makeEnquiry(address _contractAddress,uint _tokenId,address _to)public {
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"token does not belong to you.");
        Enquiry[] memory enquirys = enquiryMap[_contractAddress][_tokenId];
        Enquiry memory exitsEnquiry ;
        for(uint256 i = 0; i< enquirys.length ;i++){
            if(enquirys[i].enquiryAddress  == _to ){
                exitsEnquiry = enquirys[i];
            }
        }
        require(exitsEnquiry.time > block.timestamp - enquiryOutTime,"The inquiry is over 48H.");
        require(exitsEnquiry.enquiryAddress != address(0),"The inquiry user does not exist.");
        uint lockAmt = IStoryDeposit(storyDepositAddress).getLockDepositBalanceOf(exitsEnquiry.enquiryAddress ) ;
        require(lockAmt >= exitsEnquiry.price,"lock deposit Insufficient.");
        uint platformFee = exitsEnquiry.price/1000 * tradeFeeRate; //平台扣点
        uint userAmt =  exitsEnquiry.price - platformFee; //用户收款
        //clean sale order detail
        delete contractTokenSaleMap[_contractAddress][_tokenId] ;
        delete ownerOrderMap[_contractAddress][_tokenId] ;

        IERC721(_contractAddress).transferFrom(msg.sender,exitsEnquiry.enquiryAddress,_tokenId); //转移NFT
        IStoryDeposit(storyDepositAddress).transferLockDeposit(exitsEnquiry.enquiryAddress,msg.sender,userAmt);
        IStoryDeposit(storyDepositAddress).transferLockDeposit(exitsEnquiry.enquiryAddress,txServiceFeeAddress,platformFee);
        //clean other enquity 
        for(uint256 idx  = 0; idx < enquirys.length ; idx++ ){   //解除其他出价用户保证金
            Enquiry memory offer = enquirys[idx];
            if(offer.enquiryAddress != msg.sender && IStoryDeposit(storyDepositAddress).getLockDepositBalanceOf(offer.enquiryAddress) >= offer.price){ //防止释放错误 导致成交失败.
                IStoryDeposit(storyDepositAddress).freeLockDeposit(offer.enquiryAddress,offer.price);
            }
        }
        delete enquiryMap[_contractAddress][_tokenId];
        emit makeEnquiryEvent(_contractAddress,msg.sender,exitsEnquiry.enquiryAddress,_tokenId,exitsEnquiry.price,userAmt,platformFee);
    }

    //清理询价
    function cleanEnquiry(address _contractAddress,uint _tokenId) public onlyOwner{
        Enquiry[] memory enquirys = enquiryMap[_contractAddress][_tokenId];
        for(uint256 idx  = 0; idx < enquirys.length ; idx++ ){  
        Enquiry memory offer = enquirys[idx];
        if(offer.time < block.timestamp - enquiryOutTime && IStoryDeposit(storyDepositAddress).getLockDepositBalanceOf(offer.enquiryAddress) >= offer.price){ //防止释放错误 导致成交失败.
            IStoryDeposit(storyDepositAddress).freeLockDeposit(offer.enquiryAddress,offer.price);
            delete enquiryMap[_contractAddress][_tokenId][idx];
        }
      }
    }


    function getEnquirys(address _contractAddress,uint _tokenId) public view returns(Enquiry[] memory){
        return enquiryMap[_contractAddress][_tokenId];
    }


    function getSaleOrder(address _contractAddress,uint _tokenId) public view returns(bool){
         return contractTokenSaleMap[_contractAddress][_tokenId] > 0;
     }

    function getBiddingOrder(address _contractAddress,uint _tokenId) public view returns(bool){
         return biddingTokenSaleMap[_contractAddress][_tokenId].from != address(0);
    }

    function isEnquiry(address _contractAddress,uint _tokenId) public view returns(bool){
         return enquiryMap[_contractAddress][_tokenId].length > 0;
    }

    function setTxServiceFeeAddress(address _txServiceFeeAddress) public onlyOwner {
        txServiceFeeAddress = _txServiceFeeAddress;
    }
    
    function setTradeFeeRate(uint _tradeFeeRate) public onlyOwner {
        tradeFeeRate = _tradeFeeRate;
    }

    function getTxServiceFeeAddress() public view returns(address){
        return txServiceFeeAddress;
    }
 
    function getTradeFeeRate() public view returns(uint){
        return tradeFeeRate;
    }
 

}