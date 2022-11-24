// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import {StoryConf} from "./StoryConf.sol";


/**
保证金管理合约
 */
contract StoryDeposit is StoryConf{


    event depositEvent(address from,uint depositAmt,uint totalDepositAmt);
    event withDepositEvent(address to,uint depositAmt,uint balance);
    event deductDepositEvent(address from,address to,uint platformAmt,uint userAmt,uint balance);
    event lockDepositEvent(address _lockAddress);

    mapping(address=>uint) private depositMap; //保证金
    mapping(address =>bool) private lockMap; //锁定

    //质押保证金
    function deposit() payable public{
        require(msg.value > 0 ,"deposit must than zero.");
        uint depositAmt = depositMap[msg.sender] ;
        depositMap[msg.sender] = depositAmt + msg.value;
        emit depositEvent(msg.sender,msg.value,depositMap[msg.sender] );
    }

    //赎回保证金
    function withDeposit(uint amt) public{
        uint depositAmt = depositMap[msg.sender];
        require(depositAmt > 0 ,"deposit is not present.");
        require(amt > 0 ,"deduct deposit must than zero.");
        require(depositAmt > amt,"deduct deposit Out of limit." );
        require(lockMap[msg.sender],"deposit locked. ");
        depositMap[msg.sender] = depositAmt - amt;
        payable(msg.sender).transfer(amt); 
        emit withDepositEvent(msg.sender,amt,depositMap[msg.sender]);
    }

    //锁定保证金 - 全额锁仓
    function lockDeposit(address _lockAddress) public onlyOwner{
        require(depositMap[msg.sender] > 0, "The margin does not exist");
        lockMap[_lockAddress] = true;
        emit lockDepositEvent(_lockAddress);
    }

    //扣除保证金
    function deductDeposit(address _from,address _to,uint _startAmt) public onlyOwner{
        require(_startAmt > 0,"The starting price must be greater than 0.");
        require(_to == address(0),"The source address does not exist.");
        uint depositAmt = depositMap[_from];
        uint deductAmt = _startAmt /100 * StoryConf.getDepositProportion();
        require(depositAmt > deductAmt,"Insufficient security deposit.");
        uint platformDeductAmt = deductAmt /100 * StoryConf.getDepositFeeRate() ;
        require(platformDeductAmt > deductAmt,"platform deduct than deductAmt.");
        uint userDeductAmt = deductAmt - platformDeductAmt;
        require(userDeductAmt > deductAmt,"user deduct than deductAmt.");
        require( StoryConf.getDepositFeeAddress() == address(0),"The depositFeeAddress does not exist.");
        payable(StoryConf.getDepositFeeAddress()).transfer(platformDeductAmt);
        payable(_to).transfer(userDeductAmt);
        uint balanceOf = depositAmt - deductAmt;
        depositMap[_from] = balanceOf;
        delete lockMap[_from];
        emit deductDepositEvent(_from,_to,platformDeductAmt,userDeductAmt,balanceOf);
    }

    //获取保证金
    function getDeposit(address _owner) public view returns(uint){
        return depositMap[_owner];
    }



}