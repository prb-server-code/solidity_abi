// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TKMStaking4B is Pausable, Ownable {
    address public tokenHolder; // 토큰 보관할 지갑 주소(NFTHolder 주소를 사용)

    // stake id: 16, 17, 18
    mapping(uint256 => ERC20) public tokens;

    // stake id: 16, 17, 18
    mapping(uint256 => bool) public stakeIds;

    // 스테이킹 인덱스
    uint256 public stakingIdx;

    // // 스테이킹 참여(참여 지갑, 블록 넘버, stakeId, 스테이킹 인덱스, 스테이킹 토큰 수량)
    event Stake(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx, uint256 amount);
    // // 스테이킹 회수
    event Withdraw(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx);
    // 스테이킹 보상
    event Harvest(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx);

    /////////////////////////////////////////////////////
    // Staking
    // Staking 일정
    struct staking {
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간 (필요시 사용)
        uint256 minTokenAmount; // 최소 토큰 수량
        uint256 perTokenAmount; // 스테이킹 단위
        uint256 curTokenAmount; // 현재까지 쌓인 토큰 수량
    }

    // stake id별 스테이킹
    mapping(uint256 => staking) public stakings;

    // 스테이킹 현황
    struct stakingProgress {
        address user; // 유저 지갑 주소
        uint256 stakeId; // stake id
        uint256 stakeAmount; // 스테이킹한 토큰 수량
    }

    // 스테이킹 현황(스테이킹 인덱스 => 현황 정보)
    mapping(uint256 => stakingProgress) public progressing;

    // 스테이킹 여부(지갑 => stake id => stake 여부)
    mapping(address => mapping(uint256 => bool)) public stakeJoin;

    constructor(address _TKMToken, address _DTCToken, address _TokenHolder) {
        tokenHolder = _TokenHolder;

        tokens[16] = ERC20(payable(_TKMToken));
        tokens[17] = ERC20(payable(_DTCToken));
        tokens[18] = ERC20(payable(_TKMToken));

        stakeIds[16] = true;
        stakeIds[17] = true;
        stakeIds[18] = true;
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
        uint256 _perTokenAmount
    ) public onlyOwner {
        // 종료 시간만 변경 가능
        if(0 != stakings[_stakeId].startTime) {
            require(_endTime > stakings[_stakeId].startTime, "[TKMStaking4B][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStaking4B][setStaking]: _endTime is under now");
            stakings[_stakeId].endTime = _endTime;
            return;
        }

        staking storage newStake = stakings[_stakeId];
        newStake.startTime = _startTime;
        newStake.endTime = _endTime;
        newStake.minTokenAmount = _minTokenAmount;
        newStake.perTokenAmount = _perTokenAmount;
    }

    // 스테이킹 참여
    function stake(uint256 _stakeId, uint256 _amount) public whenNotPaused {
        // stake id 체크
        require(true == stakeIds[_stakeId], "[TKMStaking4B][stake]: invalid stake id");

        // stake 상태 체크
        require(false == stakeJoin[msg.sender][_stakeId], "[TKMStaking4B][stake]: already staked");
        stakeJoin[msg.sender][_stakeId] = true;

        // 기간 체크
        if(0 != stakings[_stakeId].endTime) {
            require(stakings[_stakeId].endTime >= block.timestamp, "[TKMStaking4B][stake]: staking is ended");
        }
        require(stakings[_stakeId].startTime <= block.timestamp, "[TKMStaking4B][stake]: staking is not started");

        // minTokenAmount 체크
        require(stakings[_stakeId].minTokenAmount <= _amount, "[TKMStaking4B][stake]: Staking amount not enough");

        // perTokenAmount 체크
        require(_amount % stakings[_stakeId].perTokenAmount == 0, "[TKMStaking4B][stake]: Staking amount invalid");

        stakings[_stakeId].curTokenAmount += _amount;

        // 토큰 전송
        require(tokens[_stakeId].transferFrom(msg.sender, tokenHolder, _amount));
        
        // 스테이킹 인덱스 증가
        ++stakingIdx;

        // 현황 기록
        stakingProgress storage progress = progressing[stakingIdx];
        progress.user = msg.sender;
        progress.stakeId = _stakeId;
        progress.stakeAmount = _amount;

        emit Stake(msg.sender, block.number, _stakeId, stakingIdx, _amount);
    }

    // 회수
    function withdraw(uint256 _stakingIdx) public whenNotPaused {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking4B][withdraw]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking4B][withdraw]: not Owner");

        uint256 amount = progressing[_stakingIdx].stakeAmount;
        uint256 stakeId = progressing[_stakingIdx].stakeId;

        // stake 상태 갱신
        stakeJoin[msg.sender][stakeId] = false;

        // 기록 제거
        delete progressing[_stakingIdx];

        // 토큰 돌려주기
        require(tokens[stakeId].transferFrom(tokenHolder, msg.sender, amount));

        emit Withdraw(msg.sender, block.number, stakeId, _stakingIdx);
    }
    
    // harvest
    function harvest(uint256 _stakingIdx) public whenNotPaused {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking4B][harvest]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking4B][harvest]: not Owner");

        emit Harvest(msg.sender, block.number, progressing[_stakingIdx].stakeId, _stakingIdx);
    }
}
