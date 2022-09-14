// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Owner.sol";

contract TKMInoA is Owner {
    ERC721 public TKMBox;
    address public Operator; // 토큰 분배할 지갑 주소

    // 구매 유저, NFT ID
    event Sale(address indexed from, uint8 indexed order, uint256 indexed boxId);

    /////////////////////////////////////////////////////
    // Box Sale
    // box sale 일정
    struct saleOrder {
        uint256 startBoxId; // 시작 박스 인덱스
        uint256 endBoxId; // 마지막 박스 인덱스
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간
        uint256 price; // 박스 가격(klay)
        uint256 limitPerUser; // 이번 회차에 유저당 구입 가능 박스 제한 수량
    }
    // 1~6차 => Box Sale 정보
    mapping(uint8 => saleOrder) public saleOrders;
    
    // 회차별 화이트리스트
    mapping(uint8 => mapping(address => bool)) public whiteLists;

    // 회차별 현재 NFT ID
    mapping(uint8 => uint256) public currentNftIds;
    
    // 회차-유저별 구입한 박스 수량
    mapping(uint8 => mapping(address => uint256)) public boxPerUser;

    constructor(address _TKMBox, address _Operator) {
        TKMBox = ERC721(payable(_TKMBox));
        Operator = _Operator;
    }

    // sale 회차별 설정
    function setSaleOrder(
        uint8 _order,
        uint256 _startBoxId,
        uint256 _endBoxId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint16 _limitPerUser
    ) public onlyOwner {
        require(_order > 0, "[TKMInoA][setSaleOrder]: order must be greater than zero");
        require(_order < 7, "[TKMInoA][setSaleOrder]: order must be less than seven");

        require(_endTime > block.timestamp, "[TKMInoA][setSaleOrder]: _endTime is under now");
        require(_endTime > _startTime, "[TKMInoA][setSaleOrder]: _endTime is under _startTime");
        
        require(0 == saleOrders[_order].startTime, "[TKMInoA][setSaleOrder]: this order already set");

        saleOrder storage newOrder = saleOrders[_order];
        newOrder.startBoxId = _startBoxId;
        newOrder.endBoxId = _endBoxId;
        newOrder.startTime = _startTime;
        newOrder.endTime = _endTime;
        newOrder.price = _price;
        newOrder.limitPerUser = _limitPerUser;

        currentNftIds[_order] = _startBoxId;
    }

    // 회차별 whitelist 추가
    function addWhiteList(uint8 _order, address[] memory _addresses) public onlyOwner {
        require(_order > 0, "[TKMInoA][addWhiteList]: order must be greater than zero");
        require(_order < 7, "[TKMInoA][addWhiteList]: order must be less than seven");
        
        require(0 < _addresses.length, "[TKMInoA][addWhiteList]: address must be greater than zero");

        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length; i++) {
            whiteLists[_order][_addresses[i]] = true;
        }
    }

    // Whitelist 1st minting
    function sale1() public payable {
        uint8 order = 1;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale1]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale1]: sale is ended");

        // whitelist 유저인지 체크
        require(whiteLists[order][msg.sender] == true, "[TKMInoA][sale1]: not in whitelist");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale1]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale1]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale1]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // Whitelist 2st minting
    function sale2() public payable {
        uint8 order = 2;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale2]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale2]: sale is ended");

        // whitelist 유저인지 체크
        require(whiteLists[order][msg.sender] == true, "[TKMInoA][sale2]: not in whitelist");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale2]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale2]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale2]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // Public 1st minting
    function sale3() public payable {
        uint8 order = 3;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale3]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale3]: sale is ended");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale3]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale3]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale3]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // Public 2st minting
    function sale4() public payable {
        uint8 order = 4;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale4]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale4]: sale is ended");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale4]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale4]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale4]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // OG minting
    function sale5() public payable {
        uint8 order = 5;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale5]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale5]: sale is ended");

        // whitelist 유저인지 체크
        require(whiteLists[order][msg.sender] == true, "[TKMInoA][sale5]: not in whitelist");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale5]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale5]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale5]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // Guild minting
    function sale6() public payable {
        uint8 order = 6;
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMInoA][sale6]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMInoA][sale6]: sale is ended");

        // whitelist 유저인지 체크
        require(whiteLists[order][msg.sender] == true, "[TKMInoA][sale6]: not in whitelist");

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[order].price;
        require(0 < boxAmount, "[TKMInoA][sale6]: box amount must be greater than zero");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[order][msg.sender] += boxAmount;
        require(boxPerUser[order][msg.sender] <= saleOrders[order].limitPerUser, "[TKMInoA][sale6]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[order];
        currentNftIds[order] += boxAmount;
        require(currentNftIds[order] <= saleOrders[order].endBoxId, "[TKMInoA][sale6]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, order, currentNftId + i);
        }
    }

    // ico 완료 후 지정한 주소로 보관 중인 이더 출금
    function withdrawEth(address to) public onlyOwner {
        require(to != address(0), "[TKMInoA][withdrawEth]: transfer to the zero address");
        // 해당 주소로 보관 중인 이더 전체 전송
        address payable receiver = payable(to);
        receiver.transfer(address(this).balance);
    }
}
