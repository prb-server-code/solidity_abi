// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TKMBoxB is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event BoxOpen(address indexed opener, uint256 indexed tokenId);

    constructor(address _minter)
        ERC721("Three Kingdom Multiverse Box", "3KMBox_B")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, _minter);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function inoMint(address to, uint256 startId, uint256 endId) external onlyRole(MINTER_ROLE) {
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

    function boxOpen(uint256 tokenId) external whenNotPaused {
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
    ) internal whenNotPaused override(ERC721, ERC721Enumerable) {
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
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
