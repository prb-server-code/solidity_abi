// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./TKMMarketTokenA.sol";

// 3km 토큰으로 거래하는 컨트랙트
contract TKMMarketTkmBoxA is TKMMarketTokenA {
    constructor(address _TokenContract, address _NFTContract, address _holder, uint256 _fee, address _feeOwner)
        TKMMarketTokenA(_TokenContract, _NFTContract, _holder, _fee, _feeOwner) {
    }

    // 판매 등록
    function listing(uint256 tokenId, uint256 price) public virtual override {
        super.listing(tokenId, price);

        // event
        emit Listing(msg.sender, tokenId, sellItems[tokenId].price);
    }

    // 판매 취소
    function cancel(uint256 tokenId) public virtual override {
        uint256 price = sellItems[tokenId].price;
        super.cancel(tokenId);

        // event
        emit Cancel(msg.sender, tokenId, price);
    }

    // 판매 처리(ERC20)
    function sell(uint256 tokenId) public payable virtual override {
        uint256 price = sellItems[tokenId].price;
        address tokenOwner = sellItems[tokenId].tokenOwner;
        super.sell(tokenId);

        // event
        emit Sell(tokenOwner, msg.sender, tokenId, price);
    }
}
