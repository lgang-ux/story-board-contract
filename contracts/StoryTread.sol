// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "./interface/IERC721.sol";
import {StoryDeposit} from "./StoryDeposit.sol";
import {StoryConf} from "./StoryConf.sol";

/**
交易模块
 */
contract StoryTread is Ownable ,StoryConf {

    event sellevent(address _contractAddress,address _from,uint _tokenId,uint _amt,uint _orderNo);
    event biddingSellEvent(address _contractAddress,address _from,uint _tokenId,uint startPrice,uint minAddPirce,int limitPrice,uint strtDate,uint endDate,uint _orderNo);
    event buyEvent(address _contractAddress,address _from,address _to,uint _tokenId,uint _amt,int _type,uint _orderNo);
    event cancelEvent(address _contractAddress,  address _from,uint _tokenId,uint _orderNo);
    event auctionEvent(address _contractAddress,address _from,uint _tokenId,uint _orderNo);
    event officePiceEvent(address _contractAddress,address _from,uint _tokenId,uint _officePice,uint _orderNo);

    //当前订单挂点信息
    mapping(address => mapping(uint=>Order)) private orderMap;
    //成交历史订单信息
    mapping(address => mapping(uint=>Order[])) private orderMapHis;
    //订单号存储
    mapping(address => mapping(uint=>OrderNoInfo)) private orderNoInfoMap;
    //报价信息合约地址=>tokenid=>orderNo =>出价列表
    mapping(address => mapping(uint=>mapping(uint =>OfficePiceInfo[]))) private officePiceMapList;
    //最新高出价 合约地址=>tokenid=>orderNo =>出价
    mapping(address => mapping(uint=>mapping(uint =>OfficePiceInfo))) private officePiceMap;


     struct OfficePiceInfo{
        address officeWoner;//报价人
        address contractAddress;//nft合约地址
        uint tokenId;//tokenId
        uint orderNo;//报价订单号
        uint officePice;//出价
        uint  officeTime;//出价时间
     }
    
     struct OrderNoInfo{
         address contractAddress;//nft合约地址
         uint tokenId ;
         uint orderNo;
    }

    struct Order{
        uint  orderNo;
        address from ;
        address contractAddress;
        uint tokenId ; 
        uint price; //交易金额
        address to; //购买者
        bool status; //交易状态
        int  _type;//0 出价单 1 竞拍订单
        uint startDate; //开始时间
        uint  endDate; //结束时间
        uint raisePrice; //最低加价
    }

    address private storyDepositAddress; //保证金合约
    constructor(address _storyDepositAddress) {
        storyDepositAddress = _storyDepositAddress;
    }



     //挂单
     function sell(address _contractAddress,uint _tokenId, uint _price) public{
        require(checkSell(_contractAddress,_tokenId),"The same TokenId cannot be placed repeatedly!");
        require(_price > 0,"sell price must than zero.");
        //检查tokenId 是否属于msg.sender
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"tokenId not belong to wallet.");
        //授权转出NFT 至 平台合约
        IERC721(_contractAddress).transferFrom(msg.sender,address(this),_tokenId);
        uint orderNo=createOrderNo(_contractAddress,_tokenId);
        //记录当前订单
        uint endDate = block.timestamp + 360*24*60*60;
        orderMap[_contractAddress][_tokenId]=Order(orderNo,msg.sender,_contractAddress,_tokenId,_price,address(0),false,0,block.timestamp,endDate,0);
        emit sellevent(_contractAddress,msg.sender,_tokenId,_price,orderNo);
    }


     //正常订单成交
     function buy(address _contractAddress,uint _tokenId) public payable {
        require(!checkSell(_contractAddress,_tokenId),"The order does not exist or has been filled!");
        Order memory _order=orderMap[_contractAddress][_tokenId];
        uint platformFee = msg.value/1000 * StoryConf.getTradeFeeRate(); //平台扣点
        uint userAmt = msg.value - platformFee; //用户
        require(_order._type ==0,"This is not a normal sales order. We can't close the deal.");
        require(_order.price <=msg.value,"the amount filled ");
        IERC721(_contractAddress).transferFrom(address(this),msg.sender,_tokenId);
        payable(_order.from).transfer(userAmt); 
        payable(StoryConf.getTxServiceFeeAddress()).transfer(platformFee);
        _order.to=msg.sender;
        _order.status = true;
        orderMap[_contractAddress][_tokenId]=_order;
        orderMapHis[_contractAddress][_tokenId].push(_order);//售出后存日历史表
        emit buyEvent(_contractAddress,_order.from,msg.sender,_tokenId,msg.value,_order._type,_order.orderNo);
    }

    /**
        竞拍挂单
        _contractAddress 合约地址
        _tokenId TokenId
        startPrice 起拍价格
        minAddPrice 最小加价
        limitPrice 是否限价
        startDate 开始时间
        endDate 结束时间
     */
     function biddingSell(address _contractAddress,uint _tokenId, uint startPrice,uint minAddPirce,int limitPrice,uint strtDate,uint endDate) public{
        require(checkSell(_contractAddress,_tokenId),"The same TokenId cannot be placed repeatedly!");
        require(startPrice > 0,"The starting price must be greater than 0.");
        require(minAddPirce > 0,"The minimum markup must be greater than 0.");
        require(endDate > block.timestamp,"endDate less than timestamp.");
        //检查tokenId 是否属于msg.sender
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"tokenId not belong to wallet.");
        //授权转出NFT 至 平台合约
        IERC721(_contractAddress).transferFrom(msg.sender,address(this),_tokenId);
        uint orderNo=createOrderNo(_contractAddress,_tokenId);
        //记录当前订单
        orderMap[_contractAddress][_tokenId]=Order(orderNo,msg.sender,_contractAddress,_tokenId,1,address(0),false,1,strtDate,endDate,minAddPirce);
        emit biddingSellEvent(_contractAddress,msg.sender,_tokenId,startPrice,minAddPirce,limitPrice,strtDate,endDate,orderNo);
    }

    //竞拍成交
     function biddingBuy(address _contractAddress,uint _tokenId) public payable {
        require(!checkSell(_contractAddress,_tokenId),"The order does not exist or has been filled!");
        Order memory _order=orderMap[_contractAddress][_tokenId];
        require(_order._type == 1,"No auction order, no transaction.");
        uint platformFee = msg.value/1000 * StoryConf.getTradeFeeRate(); //平台扣点
        uint userAmt = msg.value - platformFee; //用户
        require( isSelled(_contractAddress,  _tokenId),"The order does not exist or has been filled!");  //检查时间未受已经结束
        OfficePiceInfo memory officePiceInfo= officePiceMap[_contractAddress][_tokenId][_order.orderNo]; //获取最高价
        require(officePiceInfo.officePice <= msg.value,"the amount filled");
        require(officePiceInfo.officeWoner ==msg.sender,"the officeWoner filled");
        IERC721(_contractAddress).transferFrom(address(this),msg.sender,_tokenId);
        payable(_order.from).transfer(userAmt); 
        payable(StoryConf.getTxServiceFeeAddress()).transfer(platformFee);
        _order.to=msg.sender;
        _order.status = true;
        orderMap[_contractAddress][_tokenId]=_order;
        orderMapHis[_contractAddress][_tokenId].push(_order);
        emit buyEvent(_contractAddress,_order.from,msg.sender,_tokenId,msg.value,_order._type,_order.orderNo);
        
    }



    //撤销订单（未成交 和 没有报价的情况下 可以直接撤销）
    function cancel(address _contractAddress,uint _tokenId) public {
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"tokenId not belong to wallet.");
        Order memory order =  orderMap[_contractAddress][_tokenId];
        require(order.from == msg.sender ,"Order does not exist. ");
        require(order.status,"The order is sealed and cannot be cancelled.");
        OfficePiceInfo memory c_officePiceInfo=  officePiceMap[_contractAddress][_tokenId][order.orderNo];
        require(order._type == 1 && c_officePiceInfo.officePice > 0 ,"There's an offer. It can't be undone.");
        IERC721(_contractAddress).transferFrom(address(this),order.from,_tokenId);
        delete  orderMap[_contractAddress][_tokenId];
        emit cancelEvent(_contractAddress, msg.sender,_tokenId, order.orderNo);
    }

    //处理流拍情况,只是处理有出价的情况
    function auction(address _contractAddress,uint _tokenId,uint _orderNo) public{
        require(IERC721(_contractAddress).ownerOf(_tokenId) == msg.sender ,"tokenId not belong to wallet.");
        Order memory order =  orderMap[_contractAddress][_tokenId];
        require(order.from == msg.sender ,"Order does not exist. ");
        require(order.status,"The order is sealed and cannot be cancelled.");
        require(order._type == 0,"The order type is incorrect.");
        OfficePiceInfo memory c_officePiceInfo=  officePiceMap[_contractAddress][_tokenId][_orderNo];
        require(c_officePiceInfo.officePice == 0,"No quotation information, non-streaming order.");
        require(block.timestamp - order.endDate < StoryConf.getExpiration(),"Not more than Time, can not be counted as a lost order.");
        address officeWallet = c_officePiceInfo.officeWoner; //找到出价最高的
        IERC721(_contractAddress).transferFrom(address(this),order.from,_tokenId); //退回NFT
        delete orderMap[_contractAddress][_tokenId]; //删除订单
        delete officePiceMap[_contractAddress][_tokenId][_orderNo];//删除本次出价记录
        delete officePiceMapList[_contractAddress][_tokenId][_orderNo];
        emit auctionEvent(_contractAddress,officeWallet,_tokenId,_orderNo);  //创建锁定保证金事件
        
    }

    /**
        竞拍出价合约
        判断是否可以出价 时间结束 是否已经被竞拍
        判断出价金额是否大于价最高
      */
     function officePice(address _contractAddress, uint _tokenId,uint orderNo,uint _officePice) public{
        uint depositAmt = StoryDeposit(storyDepositAddress).getDeposit(msg.sender);
        require(depositAmt > depositAmt /100 * StoryConf.getDepositProportion(),"Insufficient security deposit.");
        require(!isSelled(_contractAddress,_tokenId),"the product  is sell");
        Order memory _order = orderMap[_contractAddress][_tokenId];
        require(_order.orderNo == orderNo && _order._type == 1,"order is erro" );
        OfficePiceInfo memory c_officePiceInfo=  officePiceMap[_contractAddress][_tokenId][orderNo];//获取当前挂单的nft
        require(c_officePiceInfo.officePice < _officePice,"the order office is min" );
        require(_officePice - c_officePiceInfo.officePice > _order.raisePrice,"The markup base is too small");
        OfficePiceInfo memory  officePiceInfo= OfficePiceInfo(msg.sender,_contractAddress,_tokenId,orderNo,_officePice,block.timestamp);
        officePiceMap[_contractAddress][_tokenId][orderNo]=officePiceInfo;
        officePiceMapList[_contractAddress][_tokenId][orderNo].push(officePiceInfo);
        emit officePiceEvent(_contractAddress,msg.sender,_tokenId,_officePice,orderNo);
     }




    function createOrderNo(address _contractAddress,uint _tokenId) public returns(uint){
        OrderNoInfo memory orderNoInfo= orderNoInfoMap[_contractAddress][_tokenId];
        if(orderNoInfo.tokenId > 0 ){
            orderNoInfo.tokenId=orderNoInfo.tokenId+1;
            return orderNoInfo.tokenId;
        }
        orderNoInfoMap[_contractAddress][_tokenId]=OrderNoInfo(_contractAddress,_tokenId,1);
        return 1;
        
    }

    

    /**
     验证订单是否卖出  true 未售出已过期  
     */
    function isSelled(address _contractAddress, uint _tokenId) private view returns(bool){
          address from= orderMap[_contractAddress][_tokenId].from;
          bool status= orderMap[_contractAddress][_tokenId].status;
          uint endDate= orderMap[_contractAddress][_tokenId].endDate;
          return  (from != address(0) && status==false && endDate < block.timestamp);
    }
     /**
     获取历史订单
      */
    function  getHisOrder(address _contractAddress, uint _tokenId) public view returns(Order[] memory orders,Order memory order) {
        orders= orderMapHis[_contractAddress][_tokenId];
        return (orders,orderMap[_contractAddress][_tokenId]);
    }

    /**
    获取当前最新订单
     */
    function  getOrder(address _contractAddress, uint _tokenId) public view returns(Order memory order) {
        return orderMap[_contractAddress][_tokenId];
    }


    /**
        获取当前竞拍历史出价
    */
    function  getHisOfficeOrder(address _contractAddress, uint _tokenId) public view returns(OfficePiceInfo[] memory orders) {
        return officePiceMapList[_contractAddress][_tokenId][orderMap[_contractAddress][_tokenId].orderNo];
    }
    /**
        获取当前最新出价
     */
    function  getOfficeOrder(address _contractAddress, uint _tokenId) public view returns(OfficePiceInfo memory orders) {
        return officePiceMap[_contractAddress][_tokenId][orderMap[_contractAddress][_tokenId].orderNo];
    }

    
    /**
     验证订单状态是否为false 如果为fase
     1 验证order是否为空
     2 验证订单是否已经卖出
     3 验证订单是否已经截止
     */
    function checkSell(address _contractAddress, uint _tokenId) private view returns(bool){
         address from= orderMap[_contractAddress][_tokenId].from;
         bool status= orderMap[_contractAddress][_tokenId].status;
         return from == address(0) || (from != address(0) && status==true );
    }



}