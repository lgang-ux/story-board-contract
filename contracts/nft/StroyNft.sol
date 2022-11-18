// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "../base/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../base/ERC721.sol";


contract StroyNft is ERC721, ERC721URIStorage, Ownable {

    uint private price;
    address _to;
  
    constructor(string memory name_, string memory symbol_,uint  price_) ERC721() {
        initName(name_,symbol_);
        price=price_;
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
    
    function byMintNft(address to, uint256 tokenId, string memory uri) public  payable {
        require(price > 0,"Nft unpriced");
        require(msg.value >= price,"Amount not satisfied");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        payable(_to).transfer(msg.value); 
    }



    function safeMintMultiple(address to, uint256[] memory tokenIds, string[] memory uris) public onlyOwner {
        for (uint i = 0; i < tokenIds.length; i++) {
             _safeMint(to, tokenIds[i]);
             _setTokenURI(tokenIds[i], uris[i]);
        }
    }



    function getPrice()public view returns(uint){
        return price;
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