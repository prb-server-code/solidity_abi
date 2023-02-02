// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TKMStaking3A is Pausable, Ownable {
    address public tokenHolder; // 토큰 보관할 지갑 주소(NFTHolder 주소를 사용)
    ERC20 public TKMToken; // 3km contract

    // stake id: 13, 14, 15
    mapping(uint256 => bool) public stakeIds;

    // 스테이킹 인덱스
    uint256 public stakingIdx;

    // // 스테이킹 참여(참여 지갑, 블록 넘버, stakeId, 스테이킹 인덱스, 스테이킹 토큰 수량, 락 해제 시간)
    event Stake(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx, uint256 amount, uint256 releaseTime);
    // // 스테이킹 회수
    event Withdraw(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx, uint256 rewardAmount);

    /////////////////////////////////////////////////////
    // Staking
    // Staking 일정
    struct staking {
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간 (필요시 사용)
        uint256 minTokenAmount; // 최소 토큰 수량
        uint256 curTokenAmount; // 현재까지 쌓인 토큰 수량
        uint256 maxTokenAmount; // 최대 토큰 수량
        uint256 lockDurationSecond; // 락업 기간 초단위
        uint256 rewardRate; // 수익률 (9.6% => 96)
    }

    // stake id별 스테이킹
    mapping(uint256 => staking) public stakings;

    // 스테이킹 현황
    struct stakingProgress {
        address user; // 유저 지갑 주소
        uint256 stakeId; // stake id
        uint256 stakeAmount; // 스테이킹한 토큰 수량
        uint256 rewardAmount; // 보상 받는 토큰 수량
        uint256 releaseTime; // 락 해제되는 시간
    }

    // 스테이킹 현황(스테이킹 인덱스 => 현황 정보)
    mapping(uint256 => stakingProgress) public progressing;

    constructor(address _TKMToken, address _TokenHolder) {
        TKMToken = ERC20(payable(_TKMToken));
        tokenHolder = _TokenHolder;

        stakeIds[13] = true;
        stakeIds[14] = true;
        stakeIds[15] = true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 스테이킹 정보 설정
    function setStaking(
        uint256 _stakeId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minTokenAmount,
        uint256 _maxTokenAmount,
        uint256 _lockDurationSecond,
        uint256 _rewardRate
    ) public onlyOwner {
        // 종료 시간만 변경 가능
        if(0 != stakings[_stakeId].startTime) {
            require(_endTime > stakings[_stakeId].startTime, "[TKMStaking3A][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStaking3A][setStaking]: _endTime is under now");
            stakings[_stakeId].endTime = _endTime;
            return;
        }

        staking storage newStake = stakings[_stakeId];
        newStake.startTime = _startTime;
        newStake.endTime = _endTime;
        newStake.minTokenAmount = _minTokenAmount;
        newStake.maxTokenAmount = _maxTokenAmount;
        newStake.lockDurationSecond = _lockDurationSecond;
        newStake.rewardRate = _rewardRate;
    }

    // 스테이킹 참여
    function stake(uint256 _stakeId, uint256 _amount) public whenNotPaused {
        // stake id 체크
        require(true == stakeIds[_stakeId], "[TKMStaking3A][stake]: invalid stake id");

        // 기간 체크
        if(0 != stakings[_stakeId].endTime) {
            require(stakings[_stakeId].endTime >= block.timestamp, "[TKMStaking3A][stake]: staking is ended");
        }
        require(stakings[_stakeId].startTime <= block.timestamp, "[TKMStaking3A][stake]: staking is not started");

        // minTokenAmount 체크
        require(stakings[_stakeId].minTokenAmount <= _amount, "[TKMStaking3A][stake]: Staking amount not enough");

        // maxTokenAmount 체크
        stakings[_stakeId].curTokenAmount += _amount;
        require(stakings[_stakeId].curTokenAmount <= stakings[_stakeId].maxTokenAmount, "[TKMStaking3A][stake]: Staking amount overflow");

        // 토큰 전송
        require(TKMToken.transferFrom(msg.sender, tokenHolder, _amount));
        
        // 스테이킹 인덱스 증가
        ++stakingIdx;

        // 현황 기록
        stakingProgress storage progress = progressing[stakingIdx];
        progress.user = msg.sender;
        progress.stakeId = _stakeId;
        progress.stakeAmount = _amount;
        progress.rewardAmount = _amount * stakings[_stakeId].rewardRate / 1000;
        progress.releaseTime = block.timestamp + stakings[_stakeId].lockDurationSecond;

        emit Stake(msg.sender, block.number, _stakeId, stakingIdx, _amount, progress.releaseTime);
    }

    // 회수
    function withdraw(uint256 _stakingIdx) public whenNotPaused {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking3A][withdraw]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking3A][withdraw]: not Owner");

        // 락 시간 체크
        require(block.timestamp > progressing[_stakingIdx].releaseTime, "[TKMStaking3A][withdraw]: remaining time is still left");

        uint256 rewardAmount = progressing[_stakingIdx].rewardAmount;
        uint256 amount = progressing[_stakingIdx].stakeAmount + rewardAmount;
        uint256 stakeId = progressing[_stakingIdx].stakeId;

        // 기록 제거
        delete progressing[_stakingIdx];

        // 토큰 돌려주기
        require(TKMToken.transferFrom(tokenHolder, msg.sender, amount));

        emit Withdraw(msg.sender, block.number, stakeId, _stakingIdx, rewardAmount);
    }
}
