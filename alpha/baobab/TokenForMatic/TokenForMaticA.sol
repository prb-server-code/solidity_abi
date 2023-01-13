// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TokenForMaticA is Pausable, Ownable {
    ERC20 public TKMToken;  // 3km token CA
    address public Operator; // 토큰 분배할 지갑 주소

    // 제약 사항
    // 한번 입력하면 중복 입력 불가
    // 한번 입력하면 수정 불가

    // 유저 정보 입력
    event SetClaimer(address indexed from, uint256 amount);

    // 락 토큰 찾아가기. amount = 찾아간 수량
    event Claim(address indexed from, uint256 amount);

    /////////////////////////////////////////////////////
    // 락 토큰 보관 및 지급
    // 배포 시간. 10%
    uint256 public tokenClaimTime;
    // 유저별 배포 토큰 수량. wei
    mapping(address => uint256) public tokenAmounts;
    // 유저별 락 토큰 지급 상태
    mapping(address => bool) public tokenTransfer;

    constructor(address _TKMToken, address _Operator) {
        TKMToken = ERC20(payable(_TKMToken));
        Operator = _Operator;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 찾아갈 토큰 정보 기록
    function setClaimer(address _claimer, uint256 _amount) public onlyOwner {
        require(address(0) != _claimer, "[TokenForMaticA][setClaimer]: _claimer is zero address");
        require(0 < _amount, "[TokenForMaticA][setClaimer]: _amount must be greater than zero");

        // 이미 있는지 체크
        require(0 == tokenAmounts[_claimer], "[TokenForMaticA][setClaimer]: Already exist claimer address");

        tokenAmounts[_claimer] = _amount;

        emit SetClaimer(_claimer, _amount);
    }

    // 최초로 찾아갈 수 있는 시간 설정. 한번만 가능함
    function setClaimTime(uint256 _claimTime) public onlyOwner {
        require(0 == tokenClaimTime, "[TokenForMaticA][setClaimTime]: already set token claim time");
        tokenClaimTime = _claimTime;
    }

    // 토큰 클레임
    function claim() public whenNotPaused {
        // 최초로 찾아갈 수 있는 시간이 없으면 실패
        require(0 < tokenClaimTime, "[TokenForMaticA][claim]: time is not setup yet");
        // 날짜 체크
        require(block.timestamp > tokenClaimTime, "[TokenForMaticA][claim]: remaining time is still left");
        // 이미 지급했는지 확인
        require(false == tokenTransfer[msg.sender], "[TokenForMaticA][claim]: already claimed");
        // 지급 설정
        tokenTransfer[msg.sender] = true;
        // 지급 토큰 수량
        uint256 tokenAmount = tokenAmounts[msg.sender];
        require(tokenAmount > 0, "[TokenForMaticA][claim]: receivable tokens are not found");
        // 지급 처리
        require(
            TKMToken.transferFrom(Operator, msg.sender, tokenAmount),
            "[TokenForMaticA][claim]: unable to send token, recipient may have reverted"
        );

        emit Claim(msg.sender, tokenAmount);
    }
}
