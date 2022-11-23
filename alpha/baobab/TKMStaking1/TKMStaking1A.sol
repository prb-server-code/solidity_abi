// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Owner.sol";

contract TKMStaking1A is Owner {
    ERC721 public TKMNft; // tkm nft
    address public NftHolder; // NFT 보관할 지갑 주소

    // 보상 타입. 1: 3km token, 2: dtc token, 3: gem
    uint8[] public rewardTypeList = [1, 2, 3];
    mapping(uint8 => bool) public rewardTypes;

    // 스테이킹 인덱스
    uint256 public stakingIdx;

    // 스테이킹 참여(참여 지갑, 블록 넘버, 스테이킹 인덱스, nft id 리스트)
    event Stake(address indexed from, uint256 blockNumber, uint256 stakingIdx, uint8 rewardType, uint256[] ids);
    // 스테이킹 회수
    event Withdraw(address indexed from, uint256 blockNumber, uint256 stakingIdx);
    // 스테이킹 보상
    event Claim(address indexed from, uint256 blockNumber, uint256 stakingIdx, bool ended);

    /////////////////////////////////////////////////////
    // Staking
    // Staking 일정
    struct staking {
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간
        uint8 nftAmount; // 1회 스테이킹 가능한 NFT 수량(3개)
        uint8 claimMaxCount; // 1회 스테이킹의 클레임 가능 최대 횟수
    }

    // 보상별 스테이킹
    mapping(uint8 => staking) public stakings;

    // 스테이킹 현황
    struct stakingProgress {
        address user; // 유저 지갑 주소
        uint8 rewardType; // 보상 타입
        uint8 claimCount; // 클레임 진행 횟수
        uint256[] ids; // 스테이킹한 NFT ID
    }

    // 스테이킹 현황(스테이킹 인덱스 => 현황 정보)
    mapping(uint256 => stakingProgress) public progressing;

    constructor(address _TKMNft, address _NftHolder) {
        TKMNft = ERC721(payable(_TKMNft));
        NftHolder = _NftHolder;

        // 보상 타입 기록
        for (uint256 i = 0; i < rewardTypeList.length; i++) {
            rewardTypes[rewardTypeList[i]] = true;
        }
    }

    // 스테이킹 정보 설정
    function setStaking(
        uint8 _rewardType,
        uint256 _startTime,
        uint256 _endTime,
        uint8 _nftAmount,
        uint8 _claimMaxCount
    ) public onlyOwner {
        // 종료 시간만 변경 가능
        if(0 != stakings[_rewardType].startTime) {
            require(_endTime > stakings[_rewardType].startTime, "[TKMStakingHeroA][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStakingHeroA][setStaking]: _endTime is under now");
            stakings[_rewardType].endTime = _endTime;
            return;
        }

        // 시간 체크
        require(_endTime > block.timestamp, "[TKMStakingHeroA][setStaking]: _endTime is under now");

        staking storage nation = stakings[_rewardType];
        nation.startTime = _startTime;
        nation.endTime = _endTime;
        nation.nftAmount = _nftAmount;
        nation.claimMaxCount = _claimMaxCount;
    }

    // 스테이킹 참여
    function stake(uint8 _rewardType, uint256[] memory _ids) public {
        // 보상 체크
        require(true == rewardTypes[_rewardType], "[TKMStakingHeroA][stake]: invalid reward type value");

        // 기간 체크
        require(stakings[_rewardType].startTime <= block.timestamp, "[TKMStakingHeroA][staking]: staking is not started");
        require(stakings[_rewardType].endTime >= block.timestamp, "[TKMStakingHeroA][staking]: staking is ended");

        // nft 수량 체크
        require(stakings[_rewardType].nftAmount == _ids.length, "[TKMStakingHeroA][staking]: not equal nftAmount");

        // 오너 체크
        for (uint256 i = 0; i < stakings[_rewardType].nftAmount; i++) {
            require(TKMNft.ownerOf(_ids[i]) == msg.sender, "[TKMStakingHeroA][staking]: owner invalid");
        }

        // 스테이킹 인덱스 증가
        ++stakingIdx;
        for (uint256 i = 0; i < stakings[_rewardType].nftAmount; i++) {
            TKMNft.safeTransferFrom(msg.sender, NftHolder, _ids[i]);
        }

        // 현황 기록
        stakingProgress storage progress = progressing[stakingIdx];
        progress.user = msg.sender;
        progress.rewardType = _rewardType;
        progress.claimCount = 0;
        progress.ids = _ids;

        emit Stake(msg.sender, block.number, stakingIdx, _rewardType, _ids);
    }

    // 회수
    function withdraw(uint256 _stakingIdx) public {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStakingHeroA][cancel]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStakingHeroA][cancel]: not Owner");

        // 기록 제거
        uint256[] memory ids = progressing[_stakingIdx].ids;
        delete progressing[_stakingIdx];

        // nft 돌려주기
        for (uint256 i = 0; i < ids.length; i++) {
            TKMNft.safeTransferFrom(NftHolder, msg.sender, ids[i]);
        }

        emit Withdraw(msg.sender, block.number, _stakingIdx);
    }

    // 클레임
    function claim(uint256 _stakingIdx) public {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStakingHeroA][claim]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStakingHeroA][claim]: not Owner");

        // 클레임 횟수 체크
        require(progressing[_stakingIdx].claimCount < stakings[progressing[_stakingIdx].rewardType].claimMaxCount, "[TKMStakingHeroA][claim]: claim overflow");

        // 기록 수정
        bool ended = false;
        progressing[_stakingIdx].claimCount++;
        if(progressing[_stakingIdx].claimCount >= stakings[progressing[_stakingIdx].rewardType].claimMaxCount) {
            ended = true;
        }

        emit Claim(msg.sender, block.number, _stakingIdx, ended);
    }
}
