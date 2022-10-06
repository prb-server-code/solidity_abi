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
        bool whiteList; // 화이트 리스트 적용 여부
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
        uint256 _limitPerUser,
        bool _whiteList
    ) public onlyOwner {
        require(0 == saleOrders[_order].startTime, "[TKMInoA][setSaleOrder]: this order already set");

        require(_order > 0, "[TKMInoA][setSaleOrder]: order must be greater than zero");
        // require(_order < 7, "[TKMInoA][setSaleOrder]: order must be less than seven");

        require(_endTime > block.timestamp, "[TKMInoA][setSaleOrder]: _endTime is under now");
        require(_endTime > _startTime, "[TKMInoA][setSaleOrder]: _endTime is under _startTime");

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

    // 회차별 whitelist 추가
    function addWhiteList(uint8 _order, address[] memory _addresses) public onlyOwner {
        require(_order > 0, "[TKMInoA][addWhiteList]: order must be greater than zero");
        // require(_order < 7, "[TKMInoA][addWhiteList]: order must be less than seven");

        require(0 < _addresses.length, "[TKMInoA][addWhiteList]: address must be greater than zero");

        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length; i++) {
            whiteLists[_order][_addresses[i]] = true;
        }
    }

    function sale(uint8 _order) public payable {
        require(_order > 0, "[TKMInoA][sale]: order must be greater than zero");

        // 기간 체크
        require(saleOrders[_order].startTime <= block.timestamp, "[TKMInoA][sale]: sale is not started");
        require(saleOrders[_order].endTime >= block.timestamp, "[TKMInoA][sale]: sale is ended");

        // whitelist 유저인지 체크
        if(saleOrders[_order].whiteList == true) {
            require(whiteLists[_order][msg.sender] == true, "[TKMInoA][sale]: not in whitelist");
        }

        // msg.value로 박스 갯수 체크
        uint256 boxAmount = msg.value / saleOrders[_order].price;
        require(0 < boxAmount, "[TKMInoA][sale]: box amount must be greater than zero");
        require(20 >= boxAmount, "[TKMInoA][sale]: exceeded number of boxes purchasable at one time");
        
        // 유저당 구매 갯수 제한 체크
        boxPerUser[_order][msg.sender] += boxAmount;
        require(boxPerUser[_order][msg.sender] <= saleOrders[_order].limitPerUser, "[TKMInoA][sale]: exceeded number of boxes purchasable");

        // 최대 구매 박스를 초과했는지 체크
        uint256 currentNftId = currentNftIds[_order];
        currentNftIds[_order] += boxAmount;
        require(currentNftIds[_order] - 1 <= saleOrders[_order].endBoxId, "[TKMInoA][sale]: Not enough boxes are left");
        
        for (uint256 i = 0; i < boxAmount; i++) {
            TKMBox.safeTransferFrom(Operator, msg.sender, currentNftId + i);
            emit Sale(msg.sender, _order, currentNftId + i);
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
