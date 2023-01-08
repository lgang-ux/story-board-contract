// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";


/**
保证金管理合约
 */
contract StoryDeposit is Ownable{


    event depositEvent(address _address,uint depositAmt);
    event withDepositEvent(address _address,uint withAmt,uint balanceOf);
    event lockDepositEvent(address _lockAddress,uint lockAmt,uint availableAmt);
    event transferLockDepositEvent(address from,address to,uint  deductAmt);
    event freeLockDepositEvent(address _address,uint availableAmt, uint lockAmt);

    mapping(address=>uint) private availableDepositMap; //可用保证金
    mapping(address =>uint) private lockDepositMap; //锁定保证金



    address private tradeOwnerAddress;
    modifier tradeOwner(){
        require(tradeOwnerAddress == msg.sender,"only owner call this");
        _;
    }

    function setTradeOwnerAddress(address _tradeOwner) public onlyOwner{
        tradeOwnerAddress  = _tradeOwner;
    }



    //质押保证金
    function deposit() payable public{
        require(msg.value > 0 ,"deposit must than zero.");
        uint depositAmt = availableDepositMap[msg.sender] ;
        uint availableAmt =  depositAmt + msg.value;
        availableDepositMap[msg.sender] =availableAmt;
        emit depositEvent(msg.sender,availableAmt );
    }

    //赎回保证金
    function withDeposit(uint withAmt) public{
        uint effectiveDepositAmt = availableDepositMap[msg.sender];
        require(withAmt > 0 ,"deduct deposit must than zero.");
        require(effectiveDepositAmt > withAmt,"Insufficient Available deposit." );
        uint balanceOf = effectiveDepositAmt - withAmt;
        availableDepositMap[msg.sender] = balanceOf;
        payable(msg.sender).transfer(withAmt); 
        emit withDepositEvent(msg.sender,withAmt,balanceOf);
    }
    //锁定保证金 
    function lockDeposit(address _lockAddress,uint lockAmt) public tradeOwner{
        require(availableDepositMap[_lockAddress] > lockAmt,"Insufficient available Balance.");
        uint alreadyLockAmt = lockDepositMap[_lockAddress] ;
        uint lock = alreadyLockAmt + lockAmt;
        uint available = availableDepositMap[_lockAddress] - lockAmt;
        lockDepositMap[_lockAddress] = lock;
        availableDepositMap[_lockAddress] = available;
        emit lockDepositEvent(_lockAddress,lock,available);
    }

    //转移保证金 竞拍自动成交. 
    function transferLockDeposit(address _from,address _to,uint deductAmt) public tradeOwner{
        require(deductAmt > 0,"deduct deposit must be greater than 0.");
        uint lockDepositAmt = lockDepositMap[_from];
        require(lockDepositAmt >0  && lockDepositAmt > deductAmt,"Insufficient lock-up deposit.");
        uint lockAmt = lockDepositAmt - deductAmt;
        lockDepositMap[_from] = lockAmt;
        payable(_to).transfer(deductAmt);
        emit transferLockDepositEvent(_from,_to,lockAmt);
    }

    //释放锁定保证金
    function freeLockDeposit(address _from,uint deductAmt) public tradeOwner{
        uint lockDepositAmt = lockDepositMap[_from];
        require(lockDepositAmt >= deductAmt,"Insufficient lock-up deposit.");
        lockDepositMap[_from] = lockDepositMap[_from] - deductAmt;
        availableDepositMap[_from] = availableDepositMap[_from] + deductAmt;
        emit freeLockDepositEvent(_from,availableDepositMap[_from],lockDepositMap[_from]);
    }


    //可用保证金
    function getEffectiveDepositBalanceOf(address _address) public view returns(uint){
        return availableDepositMap[_address] ;
    }
    //获取保证金锁定
    function getLockDepositBalanceOf(address _address) public view returns(uint){
        return lockDepositMap[_address];
    } 

}