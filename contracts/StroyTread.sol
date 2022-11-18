// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "./interface/IERC721.sol";
import {IStroyTreadActions} from "./interface/IStroyTreadActions.sol";
/**
交易模块
 */
contract StroyTread is Ownable ,IStroyTreadActions {


    //当前订单挂点信息
    mapping(address => mapping(uint=>Order)) private orderMap;
    //历史订单信息
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
        uint  endDate;
    }


     function sell(address _contractAddress,uint _tokenId, uint _price,int _type,uint endDate) public{
        bool checked = checkSell(_contractAddress,_tokenId);
        require(checked,"The same TokenId cannot be placed repeatedly!");
         Order memory  order= orderMap[_contractAddress][_tokenId];
        //授权转出NFT 至 平台合约
        IERC721(_contractAddress).transferFrom(msg.sender,address(this),_tokenId);
        //竞拍订单,检查是否是未售已卖出竞拍单
        if(order._type == 1 && isSelled(_contractAddress,_tokenId) 
            &&  officePiceMap[_contractAddress][_tokenId][order.orderNo].officePice == 0 ){
            return ;
        }
         uint orderNo=createOrderNo(_contractAddress,_tokenId);
        //记录当前订单
        orderMap[_contractAddress][_tokenId]=Order(orderNo,msg.sender,_contractAddress,_tokenId,_price,address(0),false,_type,endDate);
        emit sellevent(msg.sender,_contractAddress,_tokenId,_price,_type,endDate);
    }

    function createOrderNo(address _contractAddress,uint _tokenId) public returns(uint){
        OrderNoInfo memory orderNoInfo= orderNoInfoMap[_contractAddress][_tokenId];
        if(orderNoInfo.tokenId > 0 ){
            orderNoInfo.tokenId=orderNoInfo.tokenId+1;
            return orderNoInfo.tokenId;
        }else{
            orderNoInfoMap[_contractAddress][_tokenId]=OrderNoInfo(_contractAddress,_tokenId,1);
            return 1;
        }
      
    }

     /**
        竞拍出价合约
        判断是否可以出价 时间结束 是否已经被竞拍
        判断出价金额是否大于价最高
      */
     function officePice(address _contractAddress, uint _tokenId,uint orderNo,uint _officePice) public{
        require(!isSelled(_contractAddress,_tokenId),"the product  is sell");
        require(orderMap[_contractAddress][_tokenId].orderNo ==orderNo,"order is erro" );
        OfficePiceInfo memory c_officePiceInfo=  officePiceMap[_contractAddress][_tokenId][orderNo];//获取当前挂单的nft
        require(c_officePiceInfo.officePice < _officePice,"the order office is min" );
        OfficePiceInfo memory  officePiceInfo= OfficePiceInfo(msg.sender,_contractAddress,_tokenId,orderNo,_officePice,block.timestamp);
        officePiceMap[_contractAddress][_tokenId][orderNo]=officePiceInfo;
        officePiceMapList[_contractAddress][_tokenId][orderNo].push(officePiceInfo);
        emit officePiceEvent(msg.sender,_contractAddress,_tokenId,orderNo,_officePice);
     }

    /**
        成交订单
    */
     function buy(address _contractAddress,uint _tokenId) public payable {
        bool ischeckSell=  checkSell(_contractAddress,_tokenId);
        require(!ischeckSell,"The order does not exist or has been filled!");
        Order memory _order=orderMap[_contractAddress][_tokenId];
        if(_order._type ==0){
            require(_order.price <=msg.value,"the amount filled ");
            IERC721(_contractAddress).transferFrom(address(this),msg.sender,_tokenId);
            payable(_order.from).transfer(msg.value); 
            _order.to=msg.sender;
            _order.status = true;
            orderMap[_contractAddress][_tokenId]=_order;
            orderMapHis[_contractAddress][_tokenId].push(_order);//售出后存日历史表
        }else if (_order._type ==1){
            //检查时间未受已经结束
            require( isSelled(_contractAddress,  _tokenId),"The order does not exist or has been filled!");
            //获取最高价
           OfficePiceInfo memory officePiceInfo= officePiceMap[_contractAddress][_tokenId][_order.orderNo];
           require(officePiceInfo.officePice <= msg.value,"the amount filled");
           require(officePiceInfo.officeWoner ==msg.sender,"the officeWoner filled");
           IERC721(_contractAddress).transferFrom(address(this),msg.sender,_tokenId);
            payable(_order.from).transfer(msg.value); 
            _order.to=msg.sender;
            _order.status = true;
            orderMap[_contractAddress][_tokenId]=_order;
            orderMapHis[_contractAddress][_tokenId].push(_order);
        }
         emit buyEvent(msg.sender,_contractAddress,_tokenId,_order.orderNo,msg.value,_order._type);
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