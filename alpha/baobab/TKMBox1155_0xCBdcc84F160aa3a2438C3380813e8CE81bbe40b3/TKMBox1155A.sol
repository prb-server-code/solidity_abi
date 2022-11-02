// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Owner.sol";
import "./TKM1155Collection.sol";

contract TKMBox1155A is ERC1155, ERC1155Supply, TKM1155Collection, Owner, Minter {
    using Strings for uint256;

    string public name = "3KM Mystery Box A";
    string public symbol = "3KMBoxA";
    
    event BoxOpen(address indexed opener, uint256 indexed tokenId);

    constructor(address minter_)
        ERC1155("https://alpha-api.prunemarket.xyz:552/nft/ino/tkm/")
        Minter(minter_)
    {}

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory base = super.uri(tokenId);
        return string(abi.encodePacked(base, tokenId.toString()));
    }
    
    function inoMint(uint256[] memory ids, uint256[] memory amounts) external onlyMinter {
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                1 > balanceOf(msg.sender, ids[i]),
                "TKMBox1155A: Already exist token id"
            );
        }

        _mintBatch(msg.sender, ids, amounts, "");
    }

    function boxOpen(uint256 tokenId) external {
        require(
            0 < balanceOf(msg.sender, tokenId),
            "TKMBox1155A: only token owner can open"
        );

        _burn(msg.sender, tokenId, 1);
        emit BoxOpen(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply, TKM1155Collection) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
