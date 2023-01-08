// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;

interface IERC721{

    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external returns (bool);
    function approve(address to, uint256 tokenId) external;
    function transferFrom( address from, address to, uint256 tokenId ) external;
    function safeTransferFrom(address from,address to, uint256 amount, bytes memory data) external ;
    function ownerOf(uint256 tokenId) external returns (address)  ;
}