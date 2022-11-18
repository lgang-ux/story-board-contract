// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

interface IStroyTreadActions{
  //sell 销售挂单合约
  event sellevent(address sender,address _contractAddress,uint _tokenId,uint _price,int _type,uint endDate);

  // officePice 出价销售
  event officePiceEvent(address sender,address _contractAddress, uint _tokenId,uint orderNo,uint _officePice);

 //buy成交合约
 event buyEvent(address sender,address _contractAddress,uint _tokenId,uint orderNo,uint amont,int _type);

}