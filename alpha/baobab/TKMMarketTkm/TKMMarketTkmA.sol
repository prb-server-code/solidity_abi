// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./TKMMarketTokenA.sol";

// 3km 토큰으로 NFT, 아이템 거래하는 컨트랙트
contract TKMMarketTkmA is TKMMarketTokenA {
    constructor(address _TokenContract, address _NFTContract, address _holder, address[2] memory _feeOwner)
        TKMMarketTokenA(_TokenContract, _NFTContract, _holder, _feeOwner) {
    }

    // NFT 판매 등록
    function listing(uint256 tokenId, uint256 price) public virtual override {
        require(price >= 0.001 ether, "listing: price must greater than 0.001 ether");
        require(price < 1000000000 ether, "listing: price must less than 1000 million");

        super.listing(tokenId, price);

        // event
        emit Listing(msg.sender, tokenId, price, listingIdx);
    }

    // 아이템 판매 등록
    function listingItem(uint256 itemId, uint256 amount, uint256 price) public virtual override {
        require(price >= 0.001 ether, "listingItem: price must greater than 0.001 ether");
        require(price < 1000000000 ether, "listingItem: price must less than 1000 million");

        super.listingItem(itemId, amount, price);

        // event
        emit ListingItem(msg.sender, itemId, amount, price, listingIdx);
    }

    // NFT 판매 취소
    function cancel(uint256 _listingIdx) public virtual override {
        uint256 tokenId = sellItems[_listingIdx].tokenId;
        uint256 price = sellItems[_listingIdx].price;
        super.cancel(_listingIdx);

        // event
        emit Cancel(msg.sender, tokenId, price, _listingIdx);
    }

    // NFT 판매 처리(ERC20)
    function sell(uint256 _listingIdx) public payable virtual override {
        uint256 price = sellItems[_listingIdx].price;
        require(0 < price, "sell: not exist in sell items");

        address tokenOwner = sellItems[_listingIdx].tokenOwner;
        uint256 tokenId = sellItems[_listingIdx].tokenId;

        super.sell(_listingIdx);

        // event
        emit Sell(tokenOwner, msg.sender, tokenId, price, _listingIdx);
    }
}
