// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Owner.sol";

contract TKMTokenSaleA is Owner {
    ERC20 public TKMToken;
    address public Operator; // 토큰 분배할 지갑 주소

    // 구매 유저, 토큰 판매 수량(락 물량 포함)
    event Sale(address indexed from, uint8 order, uint256 amount);

    // 락 토큰 찾아가기. order = 1 ~ 18, amount = 1회 찾아간 수량
    event Claim(address indexed from, uint8 order, uint256 amount);

    /////////////////////////////////////////////////////
    // Token Sale
    // token sale 일정
    struct saleOrder {
        uint256 totalAmount; // 이번 회차에 판매할 토큰 제한 수량
        uint256 sellAmount; // 이번 회차에 판매 완료한 수량
        uint256 tokenMultiply; // 코인 * {배수} = 3KM
        uint256 limitPerUser; // 이번 회차에 유저당 구입 가능 토큰 제한 수량
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간
    }
    // 1, 2, 3차 => Token Sale 정보
    mapping(uint8 => saleOrder) public saleOrders;
    // 실제 구매한 토큰 수량에서 바로 보내줄 비율
    uint8 private tge_;
    // 현재 진행중인 회차
    uint8 public order;

    /////////////////////////////////////////////////////
    // 락 토큰 보관 및 지급
    // 토큰 상장 후 최초로 찾아갈 수 있는 시간
    uint256 public tokenClaimTime;
    // 상장 후 최초 풀리는 개월 수 이후에 지급할 횟수 별 날짜 단위
    uint8 public releaseOrderDay = 30;
    // 상장 후 최초 풀리는 개월 수 이후에 지급할 횟수
    uint8 public releaseOrderCount = 24;
    // 유저별 남은 토큰. 1회 수량
    mapping(address => uint256) public lockedTokens;
    // 유저별 락 토큰 지급 상태
    mapping(address => mapping(uint8 => bool)) public lockedTokenTransfer;
    // 유저별 구입한 토큰 수량
    mapping(address => mapping(uint8 => uint256)) public tokenPerUser;    

    constructor(address _TKMToken, address _Operator) {
        TKMToken = ERC20(payable(_TKMToken));
        Operator = _Operator;
        tge_ = 10; // sale 진행 시 유저 지갑에 보낼 토큰 비율
        order = 1;
    }

    // sale 회차별 설정
    function setSaleOrder(
        uint8 _order,
        uint256 _totalAmount,
        uint256 _tokenMultiply,
        uint256 _limitPerUser,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        require(_order > 0, "[TKMTokenSale][setSaleOrder]: order must be greater than zero");
        // require(_order < 4, "[TKMTokenSale][setSaleOrder]: order must be less than four");

        require(_startTime > block.timestamp, "[TKMTokenSale][setSaleOrder]: _startTime is under now");
        require(_endTime > block.timestamp, "[TKMTokenSale][setSaleOrder]: _endTime is under now");
        require(_endTime > _startTime, "[TKMTokenSale][setSaleOrder]: _endTime is under _startTime");

        // 없으면 기록
        if (0 == saleOrders[_order].totalAmount) {
            saleOrder storage newOrder = saleOrders[_order];
            newOrder.totalAmount = _totalAmount;
            newOrder.sellAmount = 0;
            newOrder.tokenMultiply = _tokenMultiply;
            newOrder.limitPerUser = _limitPerUser;
            newOrder.startTime = _startTime;
            newOrder.endTime = _endTime;
            return;
        }

        // 전체 수량 제외하고 수정 가능
        saleOrders[_order].tokenMultiply = _tokenMultiply;
        saleOrders[_order].limitPerUser = _limitPerUser;
        saleOrders[_order].startTime = _startTime;
        saleOrders[_order].endTime = _endTime;
    }

    // ico 차수 증가. 진행중인 회차 종료시 호출해야 함
    function incOrder() public onlyOwner {
        // 진행중인 차수의 미판매 수량 다음으로 넘기기
        uint256 remainTokenAmount = saleOrders[order].totalAmount - saleOrders[order].sellAmount;

        // 진행중인 차수 증가
        order++;

        // 다음 회차에 증가
        saleOrders[order].totalAmount += remainTokenAmount;
    }

/*
    struct saleOrder {
        uint256 totalAmount; // 이번 회차에 판매할 토큰 제한 수량
        uint256 sellAmount; // 이번 회차에 판매 완료한 수량
        uint256 tokenMultiply; // // 코인 * {배수} = 3KM
        uint256 limitPerUser; // 이번 회차에 유저당 구입 가능 토큰 제한 수량
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간
        mapping(address => uint256) tokenPerUser; // 이번 회차에 유저별 구입한 토큰 수량
    }
*/
    // ORK 토큰 요청
    function sale() public payable {
        // 진행중인지 체크
        require(0 < saleOrders[order].totalAmount, "[TKMTokenSale][sale]: data is not found");
        // 코인 수량 체크
        require(1 ether <= msg.value, "[TKMTokenSale][sale]: value should not be less than 1 ether");
        // 기간 체크
        require(saleOrders[order].startTime <= block.timestamp, "[TKMTokenSale][sale]: sale is not started");
        require(saleOrders[order].endTime >= block.timestamp, "[TKMTokenSale][sale]: sale is ended");

        // 구매 토큰
        uint256 validBuyToken = saleOrders[order].tokenMultiply * msg.value;

        // 남은 토큰
        uint256 validSellToken = saleOrders[order].totalAmount - saleOrders[order].sellAmount;
        // 현재 판매한 수량 증가
        saleOrders[order].sellAmount += validBuyToken;

        // 남은 토큰 비교
        require(validSellToken >= validBuyToken, "[TKMTokenSale][sale]: tokens are sold out");

        // 유저의 현재 구매 토큰으로 구매 가능한 수량 체크
        uint256 boughtToken = tokenPerUser[msg.sender][order];
        // 유저의 구매 내역 증가
        tokenPerUser[msg.sender][order] += validBuyToken;
        require(saleOrders[order].limitPerUser >= boughtToken + validBuyToken, "[TKMTokenSale][sale]: can not buy more than allocated ammount of tokens");

        // 비율 계산
        uint256 sendToken = (validBuyToken * tge_) / 100;
        // 남은 토큰
        uint256 remainToken = validBuyToken - sendToken;
        lockedTokens[msg.sender] += remainToken / releaseOrderCount;

        // ico 요청자에게 토큰 전송
        require(
            TKMToken.transferFrom(Operator, msg.sender, sendToken),
            "[TKMTokenSale][sale]: unable to send token, recipient may have reverted"
        );

        emit Sale(msg.sender, order, validBuyToken);
    }

    // 토큰 상장 후 최초로 찾아갈 수 있는 시간 설정. 한번만 가능함
    function setTokenClaimTime(uint256 _tokenClaimTime) public onlyOwner {
        require(0 == tokenClaimTime, "[TKMTokenSale][setTokenClaimTime]: already set token claim time");
        tokenClaimTime = _tokenClaimTime;
    }
/*
    // 토큰 상장 후 최초로 찾아갈 수 있는 시간
    uint256 private tokenClaimTime;
    // 상장 후 최초 풀리는 개월 수 이후에 지급할 횟수 별 날짜 단위
    uint8 public releaseOrderDay = 30;
    // 상장 후 최초 풀리는 개월 수 이후에 지급할 횟수
    uint8 public releaseOrderCount = 18;
    // 유저별 남은 토큰. 1회 수량
    mapping(address => uint256) public lockedTokens;
    // 유저별 락 토큰 지급 상태
    mapping(address => mapping(uint8 => bool)) public lockedTokenTransfer;
*/
    // 락상태 토큰 전송 요청 기능
    function claim(uint8 claimOrder) public {
        // 최초로 찾아갈 수 있는 시간이 없으면 실패
        require(0 < tokenClaimTime, "[TKMTokenSale][claim]: time is not setup yet");
        // order 값 체크
        require(0 < claimOrder && releaseOrderCount >= claimOrder, "[TKMTokenSale][claim]: invalid order");
        // 이미 지급했는지 확인
        require(false == lockedTokenTransfer[msg.sender][claimOrder], "[TKMTokenSale][claim]: already claimed");
        // 지급 설정
        lockedTokenTransfer[msg.sender][claimOrder] = true;
        // 날짜 체크
        // uint256 releaseTime = tokenClaimTime + ((releaseOrderDay * (uint256(claimOrder) - 1)) * 86400); // 1 days == 86400
        uint256 releaseTime = tokenClaimTime + ((15 * (uint256(claimOrder) - 1)) * 60);     // 15분
        require(block.timestamp > releaseTime, "[TKMTokenSale][claim]: remaining time is still left");
        // 지급 토큰 수량
        uint256 tokenAmount = lockedTokens[msg.sender];
        require(tokenAmount > 0, "[TKMTokenSale][claim]: receivable tokens are not found");
        // 지급 처리
        require(
            TKMToken.transferFrom(Operator, msg.sender, tokenAmount),
            "[TKMTokenSale][claim]: unable to send token, recipient may have reverted"
        );

        emit Claim(msg.sender, claimOrder, tokenAmount);
    }

    // ico 완료 후 지정한 주소로 보관 중인 이더 출금
    function withdrawEth(address to) public onlyOwner {
        require(to != address(0), "[TKMTokenSale][withdrawEth]: transfer to the zero address");
        // 해당 주소로 보관 중인 이더 전체 전송
        address payable receiver = payable(to);
        receiver.transfer(address(this).balance);
    }
}
