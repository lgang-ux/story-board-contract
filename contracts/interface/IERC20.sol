// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;


interface IERC20 {
    function balanceOf(address _account) external view returns (uint256);
    function transferFrom( address from,address to, uint256 amount) external   returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external  returns (bool);
}

