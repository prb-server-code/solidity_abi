// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Owner.sol";

contract TKMBox is ERC721, ERC721Enumerable, ERC721URIStorage, Owner, Minter {
    event BoxOpen(address indexed opener, uint256 indexed tokenId);

    // owned box
    struct Boxes {
        uint256 tokenId;
        bool isOpened;
    }

    // Mapping from token ID to box opened
    mapping(uint256 => bool) private _boxOpened;

    constructor(address minter_)
        ERC721("Three Kingdom Multiverse Box", "3KMBox")
        Minter(minter_)
    {}

    function inoMint(uint256 startId, uint256 endId) external onlyMinter {
        for (uint256 k = startId; k <= endId; k++) {
            _safeMint(msg.sender, k);
        }
    }

    function isOpened(uint256 tokenId) external view returns (bool) {
        return _boxOpened[tokenId];
    }

    function collection()
        external
        view
        returns (string memory, Boxes[] memory)
    {
        uint256 boxAmount = ERC721.balanceOf(msg.sender);
        Boxes[] memory boxes = new Boxes[](boxAmount);
        for (uint256 i = 0; i < boxAmount; i++) {
            uint256 tokenId = ERC721Enumerable.tokenOfOwnerByIndex(
                msg.sender,
                i
            );
            boxes[i].tokenId = tokenId;
            boxes[i].isOpened = _boxOpened[tokenId];
        }
        return (_baseURI(), boxes);
    }

    function boxOpen(uint256 tokenId) external {
        require(
            msg.sender == ownerOf(tokenId),
            "TKMBox: only token owner can open"
        );
        require(
            false == _boxOpened[tokenId],
            "TKMBox: already token is opened"
        );
        _boxOpened[tokenId] = true;
        emit BoxOpen(msg.sender, tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://alpha-api.prunemarket.xyz:552/nft/ino/TKM/";
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
