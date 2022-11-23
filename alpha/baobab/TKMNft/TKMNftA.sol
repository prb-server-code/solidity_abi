// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Owner.sol";

contract TKMNftA is ERC721, ERC721Enumerable, ERC721URIStorage, Owner, Minter, Holder {
    event NftBurn(uint256 indexed tokenId, uint16 indexed reason);

    // nft token id
    uint256 public nftId;

    constructor(address _minter, address _holder)
        ERC721("Three Kingdom Multiverse Nft", "3KMNft_A")
        Minter(_minter)
        Holder(_holder)
    {}

    function Mint(address nftOwner) external onlyMinter returns (uint256) {
        ++nftId;
        _safeMint(nftOwner, nftId);
        return nftId;
    }

    function Burn(uint256 _tokenId, uint16 reason) external onlyHolder {
        _burn(_tokenId);
        emit NftBurn(_tokenId, reason);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://alpha-api.prunemarket.xyz:552/nft/item/tkm/";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
