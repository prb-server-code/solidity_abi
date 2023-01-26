// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TKMStaking2A is Pausable, AccessControl {
    ERC721 public TKMNft; // tkm nft
    address public NftHolder; // NFT 보관할 지갑 주소

    uint8 public constant gapIndex = 9; // TKMStaking1,2와의 인덱스 보정용

    // stakeId (9 ~ 12: 3km)
    uint256[4] public stakeIdList = [9, 10, 11, 12];
    mapping(uint256 => bool) public stakeIds;

    // 스테이킹 인덱스
    uint256 public stakingIdx;

    struct stakedInfo {
        uint256 nftCount; 
        uint256 walletCount;
    }
    
    // 스테이킹별 카운트
    stakedInfo[4] public stakedInfoList;

    // 스테이킹 참여(참여 지갑, 블록 넘버, stakeId, 스테이킹 인덱스, nft id 리스트)
    event Stake(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx, uint256[] ids);
    // 스테이킹 회수
    event Withdraw(address indexed from, uint256 blockNumber, uint256 stakingIdx);
    // 스테이킹 보상
    event Harvest(address indexed from, uint256 blockNumber, uint256 stakingIdx);

    /////////////////////////////////////////////////////
    // Staking
    // Staking 일정
    struct staking {
        uint256 startTime; // 시작 시간
        uint256 endTime; // 종료 시간
        uint8 nftAmount; // 1회 스테이킹 가능한 NFT 수량(1, 3, 5, 7)
        uint256 withdrawTime; // 회수 가능한 시간
    }

    // stake id별 스테이킹
    mapping(uint256 => staking) public stakings;

    // 스테이킹 현황
    struct stakingProgress {
        address user; // 유저 지갑 주소
        uint256 stakeId; // stake id
        uint256[] ids; // 스테이킹한 NFT ID
    }

    // 스테이킹 현황(스테이킹 인덱스 => 현황 정보)
    mapping(uint256 => stakingProgress) public progressing;

    constructor(address _TKMNft, address _NftHolder) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TKMNft = ERC721(payable(_TKMNft));
        NftHolder = _NftHolder;

        // stake id 셋팅
        for (uint256 i = 0; i < stakeIdList.length; i++) {
            stakeIds[stakeIdList[i]] = true;
        }

        // stakedInfo 셋팅
        for (uint256 i = 0; i < stakeIdList.length; i++) {
            stakedInfo memory info = stakedInfo(0, 0);
            stakedInfoList[i] = info;
        }
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // 스테이킹 정보 설정
    function setStaking(
        uint256 _stakeId,
        uint256 _startTime,
        uint256 _endTime,
        uint8 _nftAmount,
        uint256 _withdrawTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // 종료 시간, 회수 시간 변경 가능
        if(0 != stakings[_stakeId].startTime) {
            require(_endTime > stakings[_stakeId].startTime, "[TKMStaking2A][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStaking2A][setStaking]: _endTime is under now");
            stakings[_stakeId].endTime = _endTime;
            stakings[_stakeId].withdrawTime = _withdrawTime;
            return;
        }

        // 시간 체크
        require(_endTime > block.timestamp, "[TKMStaking2A][setStaking]: _endTime is under now");

        staking storage newStake = stakings[_stakeId];
        newStake.startTime = _startTime;
        newStake.endTime = _endTime;
        newStake.nftAmount = _nftAmount;
        newStake.withdrawTime = _withdrawTime;
    }

    // 스테이킹 참여
    function stake(uint256 _stakeId, uint256[] memory _ids) public whenNotPaused {
        // stake id 체크
        require(true == stakeIds[_stakeId], "[TKMStaking2A][stake]: invalid stake id");

        // 기간 체크
        require(stakings[_stakeId].startTime <= block.timestamp, "[TKMStaking2A][staking]: staking is not started");
        require(stakings[_stakeId].endTime >= block.timestamp, "[TKMStaking2A][staking]: staking is ended");

        // nft 수량 체크
        require(stakings[_stakeId].nftAmount == _ids.length, "[TKMStaking2A][staking]: not equal nftAmount");

        // 오너 체크
        for (uint256 i = 0; i < stakings[_stakeId].nftAmount; i++) {
            require(TKMNft.ownerOf(_ids[i]) == msg.sender, "[TKMStaking2A][staking]: owner invalid");
        }

        // 스테이킹 인덱스 증가
        ++stakingIdx;
        for (uint256 i = 0; i < stakings[_stakeId].nftAmount; i++) {
            TKMNft.safeTransferFrom(msg.sender, NftHolder, _ids[i]);
        }

        // 현황 기록
        stakingProgress storage progress = progressing[stakingIdx];
        progress.user = msg.sender;
        progress.stakeId = _stakeId;
        progress.ids = _ids;

        // stakedInfo 갱신
        stakedInfoList[_stakeId - gapIndex].nftCount += stakings[_stakeId].nftAmount;
        stakedInfoList[_stakeId - gapIndex].walletCount += 1;

        emit Stake(msg.sender, block.number, _stakeId, stakingIdx, _ids);
    }

    // 회수
    function withdraw(uint256 _stakingIdx) public whenNotPaused {
        // 회수 가능 날짜 체크
        require(block.timestamp > stakings[progressing[_stakingIdx].stakeId].withdrawTime, "[TKMStaking2A][withdraw]: withdraw time is still left");

        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking2A][withdraw]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking2A][withdraw]: not Owner");

        // stakedInfo 갱신
        stakedInfoList[progressing[_stakingIdx].stakeId - gapIndex].nftCount -= stakings[progressing[_stakingIdx].stakeId].nftAmount;
        stakedInfoList[progressing[_stakingIdx].stakeId - gapIndex].walletCount -= 1;

        // 기록 제거
        uint256[] memory ids = progressing[_stakingIdx].ids;
        delete progressing[_stakingIdx];

        // nft 돌려주기
        for (uint256 i = 0; i < ids.length; i++) {
            TKMNft.safeTransferFrom(NftHolder, msg.sender, ids[i]);
        }

        emit Withdraw(msg.sender, block.number, _stakingIdx);
    }

    // harvest
    function harvest(uint256 _stakingIdx) public whenNotPaused {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking2A][harvest]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking2A][harvest]: not Owner");

        emit Harvest(msg.sender, block.number, _stakingIdx);
    }

    function getIds(uint256 _stakingIdx) public view returns (uint256[] memory ids) {
        return progressing[_stakingIdx].ids;
    }

    function getStakedInfo() public view returns (uint256 blockNumber, stakedInfo[4] memory stakedList) {
        return (block.number, stakedInfoList);
    }
}
