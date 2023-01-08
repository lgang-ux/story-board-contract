// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStoryTrade{
    
    function getSaleOrder(address _contractAddress,uint _tokenId) external returns(bool);

    function getBiddingOrder(address _contractAddress,uint _tokenId) external returns(bool);

     function isEnquiry(address _contractAddress,uint _tokenId) external returns(bool);
}

contract StoryNft is ERC721, ERC721URIStorage, Ownable {

    address private tradeAddress;
    uint private boxMintPrice; //只有boxMint 才可能需要价格
  
    constructor(address _tradeAddress,string memory name_, string memory symbol_,uint  price_) ERC721(name_,symbol_) {
        boxMintPrice = price_;
        tradeAddress = _tradeAddress;
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function safeMintMultiple(address to, uint256[] memory tokenIds, string[] memory uris) public onlyOwner {
        for (uint i = 0; i < tokenIds.length; i++) {
             _safeMint(to, tokenIds[i]);
             _setTokenURI(tokenIds[i], uris[i]);
        }
    }


   function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override{
        require(!IStoryTrade(tradeAddress).getSaleOrder(address(this),firstTokenId),"NFT is on sale.");
        require(!IStoryTrade(tradeAddress).getBiddingOrder(address(this),firstTokenId),"NFT is on bidding.");
        super._beforeTokenTransfer(from,to,firstTokenId,batchSize);
    }



    function getPrice()public view returns(uint){
        return boxMintPrice;
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
  
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}