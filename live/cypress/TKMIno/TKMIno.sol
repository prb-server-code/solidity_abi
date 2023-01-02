// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TKMIno is Pausable, AccessControl {
    ERC721 public TKMBox;
    address public Operator;

    event Sale(address indexed from, uint8 indexed order, uint256 indexed boxId);

    /////////////////////////////////////////////////////
    // Box Sale
    struct saleOrder {
        uint256 startBoxId;
        uint256 endBoxId;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 limitPerUser;
        bool whiteList;
    }
    mapping(uint8 => saleOrder) public saleOrders;
    
    mapping(uint8 => mapping(address => bool)) public whiteLists;

    mapping(uint8 => uint256) public currentNftIds;
    
    mapping(uint8 => mapping(address => uint256)) public boxPerUser;

    constructor(address _TKMBox, address _Operator) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TKMBox = ERC721(payable(_TKMBox));
        Operator = _Operator;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setSaleOrder(
        uint8 _order,
        uint256 _startBoxId,
        uint256 _endBoxId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _limitPerUser,
        bool _whiteList
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(0 == saleOrders[_order].startTime, "[TKMInoB][setSaleOrder]: this order already set");

        require(_order > 0, "[TKMInoB][setSaleOrder]: order must be greater than zero");

        require(_endTime > block.timestamp, "[TKMInoB][setSaleOrder]: _endTime is under now");
        require(_endTime > _startTime, "[TKMInoB][setSaleOrder]: _endTime is under _startTime");

        saleOrder storage newOrder = saleOrders[_order];
        newOrder.startBoxId = _startBoxId;
        newOrder.endBoxId = _endBoxId;
        newOrder.startTime = _startTime;
        newOrder.endTime = _endTime;
        newOrder.price = _price;
        newOrder.limitPerUser = _limitPerUser;
        newOrder.whiteList = _whiteList;

        currentNftIds[_order] = _startBoxId;
    }

    function addWhiteList(uint8 _order, address[] memory _addresses) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_order > 0, "[TKMInoB][addWhiteList]: order must be greater than zero");

        require(0 < _addresses.length, "[TKMInoB][addWhiteList]: address must be greater than zero");

        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length; i++) {
            whiteLists[_order][_addresses[i]] = true;
        }
    }

    function sale(uint8 _order) public payable whenNotPaused {
        require(_order > 0, "[TKMInoB][sale]: order must be greater than zero");

        require(saleOrders[_order].startTime <= block.timestamp, "[TKMInoB][sale]: sale is not started");
        require(saleOrders[_order].endTime >= block.timestamp, "[TKMInoB][sale]: sale is ended");

        if(saleOrders[_order].whiteList == true) {
            require(whiteLists[_order][msg.sender] == true, "[TKMInoB][sale]: not in whitelist");
        }

        uint256 boxAmount = msg.value / saleOrders[_order].price;
        require(boxAmount * saleOrders[_order].price == msg.value, "[TKMInoB][sale]: incorrect value");
        require(0 < boxAmount, "[TKMInoB][sale]: box amount must be greater than zero");
        require(20 >= boxAmount, "[TKMInoB][sale]: exceeded number of boxes purchasable at one time");
        
        boxPerUser[_order][msg.sender] += boxAmount;
        require(boxPerUser[_order][msg.sender] <= saleOrders[_order].limitPerUser, "[TKMInoB][sale]: exceeded number of boxes purchasable");

        uint256 currentNftId = currentNftIds[_order];
        currentNftIds[_order] += boxAmount;
        require(currentNftIds[_order] - 1 <= saleOrders[_order].endBoxId, "[TKMInoB][sale]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, _order, currentNftId + i);
        }
    }

    function withdrawEth(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "[TKMInoB][withdrawEth]: transfer to the zero address");
        address payable receiver = payable(to);
        receiver.transfer(address(this).balance);
    }
}
