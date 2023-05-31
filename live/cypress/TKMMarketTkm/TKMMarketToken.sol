// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./TKMMarketI.sol";

abstract contract TKMMarketToken is TKMMarketI, Pausable, Ownable {
    ERC20 public TokenContract_;
    ERC721 public NFTContract_;
    address public holder_;

    uint256 public listingIdx;

    // fee
    // [0] : platform fee (2.5% => 25)
    // [1] : creator fee (7.5% => 75)
    uint256[2] public fee_;
    function setFee(uint8 index, uint256 _fee) public onlyOwner {
        fee_[index] = _fee;
    }

    address[2] public feeOwner_;
    function setFeeOwner(uint8 index, address _feeOwner) public onlyOwner {
        feeOwner_[index] = _feeOwner;
    }

    struct SellItem {
        uint256 tokenId;
        uint256 price;
        address tokenOwner;
    }

    mapping(uint256 => SellItem) public sellItems;

    constructor(address _TokenContract, address _NFTContract, address _holder, address[2] memory _feeOwner) {
        TokenContract_ = ERC20(_TokenContract);
        NFTContract_ = ERC721(_NFTContract);
        holder_ = _holder;
        fee_[0] = 25;
        fee_[1] = 75;
        feeOwner_[0] = _feeOwner[0];
        feeOwner_[1] = _feeOwner[1];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    function listing(uint256 tokenId, uint256 price) public virtual override whenNotPaused {
        require(msg.sender == NFTContract_.ownerOf(tokenId), "listing: only token owner can listing");
        require(NFTContract_.isApprovedForAll(msg.sender, address(this)), "listing: not approved on this contract");

        NFTContract_.safeTransferFrom(msg.sender, holder_, tokenId);
        ++listingIdx;

        SellItem storage sellItem = sellItems[listingIdx];
        sellItem.tokenId = tokenId;
        sellItem.price = price;
        sellItem.tokenOwner = msg.sender;
    }
    
    function listingItem(uint256 /* itemId */, uint256 /* amount */, uint256 price) public virtual override whenNotPaused {
        ++listingIdx;

        SellItem storage sellItem = sellItems[listingIdx];
        sellItem.tokenId = 0;
        sellItem.price = price;
        sellItem.tokenOwner = msg.sender;
    }

    function cancel(uint256 _listingIdx) public virtual override whenNotPaused {
        require(0 < sellItems[_listingIdx].price, "cancel: not exist in sell items");
        require(msg.sender == sellItems[_listingIdx].tokenOwner, "cancel: not owner");

        if(sellItems[_listingIdx].tokenId != 0) {
            NFTContract_.safeTransferFrom(holder_, msg.sender, sellItems[_listingIdx].tokenId);
        }

        delete sellItems[_listingIdx];
    }

    function sell(uint256 _listingIdx) public payable virtual override whenNotPaused {
        require(0 < sellItems[_listingIdx].price, "sell: not exist in sell items");
        require(msg.sender != sellItems[_listingIdx].tokenOwner, "sell: you are owner");

        require(TokenContract_.balanceOf(msg.sender) >= sellItems[_listingIdx].price, "sell: Not enough token amount");
        require(TokenContract_.allowance(msg.sender, address(this)) >= sellItems[_listingIdx].price, "sell: Not enough allowanced token amount");
        
        uint256[2] memory sellFee;
        sellFee[0] = (sellItems[_listingIdx].price * fee_[0]) / 1000;
        sellFee[1] = (sellItems[_listingIdx].price * fee_[1]) / 1000;

        // platform fee
        if(0 < sellFee[0]) {
            require(TokenContract_.transferFrom(msg.sender, feeOwner_[0], sellFee[0]), "sell: erc20 transfer fee[0] failed");
        }
        // creator fee
        if(0 < sellFee[1]) {
            require(TokenContract_.transferFrom(msg.sender, feeOwner_[1], sellFee[1]), "sell: erc20 transfer fee[1] failed");
        }

        require(TokenContract_.transferFrom(msg.sender, sellItems[_listingIdx].tokenOwner, sellItems[_listingIdx].price - (sellFee[0] + sellFee[1])), "sell: erc20 transfer price failed");

        if(sellItems[_listingIdx].tokenId != 0) {
            NFTContract_.safeTransferFrom(holder_, msg.sender, sellItems[_listingIdx].tokenId);
        }

        delete sellItems[_listingIdx];
    }

    function cancelForce(uint256 _listingIdx) public onlyOwner {
        require(0 < sellItems[_listingIdx].price, "cancelForce: not exist in sell items");

        if(sellItems[_listingIdx].tokenId != 0) {
            NFTContract_.safeTransferFrom(holder_, sellItems[_listingIdx].tokenOwner, sellItems[_listingIdx].tokenId);
        }

        delete sellItems[_listingIdx];
    }
}
