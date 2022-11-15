// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Owner.sol";

contract TKMBoxB is ERC721, ERC721Enumerable, ERC721URIStorage, Owner, Minter {
    event BoxOpen(address indexed opener, uint256 indexed tokenId);

    constructor(address minter_)
        ERC721("Three Kingdom Multiverse Box", "3KMBox_B")
        Minter(minter_)
    {}

    function inoMint(address to, uint256 startId, uint256 endId) external onlyMinter {
        for (uint256 k = startId; k <= endId; k++) {
            _safeMint(to, k);
        }
    }

    function collection(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 boxAmount = ERC721.balanceOf(owner);
        uint256[] memory boxes = new uint256[](boxAmount);
        for (uint256 i = 0; i < boxAmount; i++) {
            uint256 tokenId = ERC721Enumerable.tokenOfOwnerByIndex(owner, i);
            boxes[i] = tokenId;
        }
        return boxes;
    }

    function boxOpen(uint256 tokenId) external {
        require(
            msg.sender == ownerOf(tokenId),
            "TKMBox: only token owner can open"
        );
        
        emit BoxOpen(msg.sender, tokenId);

        _burn(tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.prunemarket.xyz:444/nft/ino/tkm/";
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
