// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Owner.sol";

contract TKMStaking1A is Owner {
    ERC721 public TKMNft; // tkm nft
    address public NftHolder; // NFT 보관할 지갑 주소

    // stakeId (1 ~ 4: 3km, 5 ~ 8: dtc)
    uint256[] public stakeIdList = [1, 2, 3, 4, 5, 6, 7, 8];
    mapping(uint256 => bool) public stakeIds;

    // 스테이킹 인덱스
    uint256 public stakingIdx;

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
        uint8 nftAmount; // 1회 스테이킹 가능한 NFT 수량(3개)
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
        TKMNft = ERC721(payable(_TKMNft));
        NftHolder = _NftHolder;

        // stake id 셋팅
        for (uint256 i = 0; i < stakeIdList.length; i++) {
            stakeIds[stakeIdList[i]] = true;
        }
    }

    // 스테이킹 정보 설정
    function setStaking(
        uint256 _stakeId,
        uint256 _startTime,
        uint256 _endTime,
        uint8 _nftAmount
    ) public onlyOwner {
        // 종료 시간만 변경 가능
        if(0 != stakings[_stakeId].startTime) {
            require(_endTime > stakings[_stakeId].startTime, "[TKMStaking1A][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStaking1A][setStaking]: _endTime is under now");
            stakings[_stakeId].endTime = _endTime;
            return;
        }

        // 시간 체크
        require(_endTime > block.timestamp, "[TKMStaking1A][setStaking]: _endTime is under now");

        staking storage newStake = stakings[_stakeId];
        newStake.startTime = _startTime;
        newStake.endTime = _endTime;
        newStake.nftAmount = _nftAmount;
    }

    // 스테이킹 참여
    function stake(uint256 _stakeId, uint256[] memory _ids) public {
        // stake id 체크
        require(true == stakeIds[_stakeId], "[TKMStaking1A][stake]: invalid stake id");

        // 기간 체크
        require(stakings[_stakeId].startTime <= block.timestamp, "[TKMStaking1A][staking]: staking is not started");
        require(stakings[_stakeId].endTime >= block.timestamp, "[TKMStaking1A][staking]: staking is ended");

        // nft 수량 체크
        require(stakings[_stakeId].nftAmount == _ids.length, "[TKMStaking1A][staking]: not equal nftAmount");

        // 오너 체크
        for (uint256 i = 0; i < stakings[_stakeId].nftAmount; i++) {
            require(TKMNft.ownerOf(_ids[i]) == msg.sender, "[TKMStaking1A][staking]: owner invalid");
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

        emit Stake(msg.sender, block.number, _stakeId, stakingIdx, _ids);
    }

    // 회수
    function withdraw(uint256 _stakingIdx) public {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking1A][withdraw]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking1A][withdraw]: not Owner");

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
    function harvest(uint256 _stakingIdx) public {
        // 스테이킹 존재 및 지갑 주소 체크
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking1A][harvest]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking1A][harvest]: not Owner");

        emit Harvest(msg.sender, block.number, _stakingIdx);
    }

    function getIds(uint256 _stakingIdx) public view returns (uint256[] memory ids) {
        return progressing[_stakingIdx].ids;
    }
}
