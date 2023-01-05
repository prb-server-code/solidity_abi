// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TKMNft is ERC721, ERC721URIStorage, Pausable, AccessControl, Ownable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant HOLDER_ROLE = keccak256("HOLDER_ROLE");

    event NftBurn(uint256 indexed tokenId, uint16 indexed reason);

    uint256 public nftId;

    constructor(address _minter, address _holder)
        ERC721("Three Kingdom Multiverse Nft", "3KMNft")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, _minter);
        _grantRole(HOLDER_ROLE, _holder);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function Mint(address nftOwner) external whenNotPaused onlyRole(MINTER_ROLE) returns (uint256) {
        ++nftId;
        _safeMint(nftOwner, nftId);
        return nftId;
    }

    function Burn(uint256 _nftId, uint16 reason) external whenNotPaused onlyRole(HOLDER_ROLE) {
        _burn(_nftId);
        emit NftBurn(_nftId, reason);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.3km.sale/nft/item/tkm/";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal whenNotPaused override(ERC721) {
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
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
