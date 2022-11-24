// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";





/**
 * 平台配置管理
 */
contract StoryConf is Ownable{

    address private txServiceFeeAddress; //交易服务费地址

    address private depositFeeAddress;//保证金地址

    uint private depositProportion = 80; //保证金必须达到当前出价的80%。 100倍

    uint private depositFeeRate = 20; //保证金扣除平台占比 20% 100倍

    uint private tradeFeeRate = 50 ;//交易服务费 5% 1000倍

    uint private expiration = 24*60*60; //竞拍付款超时时间


   
    
    function setTxServiceFeeAddress(address _txServiceFeeAddress) public onlyOwner {
        txServiceFeeAddress = _txServiceFeeAddress;
    }

    function setDepositFeeAddress(address _depositFeeAddress) public onlyOwner {
        depositFeeAddress = _depositFeeAddress;
    }

   function setDepositProportion(uint _depositProportion) public onlyOwner {
        depositProportion = _depositProportion;
    }

    
    function setDepositFeeRate(uint _depositFeeRate) public onlyOwner {
        depositFeeRate = _depositFeeRate;
    }
    
    function setTradeFeeRate(uint _tradeFeeRate) public onlyOwner {
        tradeFeeRate = _tradeFeeRate;
    }

    function setExpiration(uint _expiration) public onlyOwner{
        expiration = _expiration;
    }


    function getTxServiceFeeAddress() public view returns(address){
        return txServiceFeeAddress;
    }
    function getDepositFeeAddress() public view returns(address){
        return depositFeeAddress;
    }
    function getDepositProportion() public view returns(uint){
        return depositProportion;
    }
    function getDepositFeeRate() public view returns(uint){
        return depositFeeRate;
    }
    function getTradeFeeRate() public view returns(uint){
        return tradeFeeRate;
    }
    function getExpiration() public view returns(uint){
        return expiration;
    }

}