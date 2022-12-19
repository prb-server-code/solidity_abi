// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TKMStaking1B is Pausable, AccessControl {
    ERC721 public TKMNft;
    address public NftHolder;

    uint256[8] public stakeIdList = [1, 2, 3, 4, 5, 6, 7, 8];
    mapping(uint256 => bool) public stakeIds;

    uint256 public stakingIdx;

    struct stakedInfo {
        uint256 nftCount; 
        uint256 walletCount;
    }

    stakedInfo[8] public stakedInfoList;

    event Stake(address indexed from, uint256 blockNumber, uint256 stakeId, uint256 stakingIdx, uint256[] ids);
    event Withdraw(address indexed from, uint256 blockNumber, uint256 stakingIdx);
    event Harvest(address indexed from, uint256 blockNumber, uint256 stakingIdx);

    struct staking {
        uint256 startTime;
        uint256 endTime;
        uint8 nftAmount;
    }

    mapping(uint256 => staking) public stakings;

    struct stakingProgress {
        address user;
        uint256 stakeId;
        uint256[] ids;
    }

    mapping(uint256 => stakingProgress) public progressing;

    constructor(address _TKMNft, address _NftHolder) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        TKMNft = ERC721(payable(_TKMNft));
        NftHolder = _NftHolder;

        for (uint256 i = 0; i < stakeIdList.length; i++) {
            stakeIds[stakeIdList[i]] = true;
        }

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

    function setStaking(
        uint256 _stakeId,
        uint256 _startTime,
        uint256 _endTime,
        uint8 _nftAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if(0 != stakings[_stakeId].startTime) {
            require(_endTime > stakings[_stakeId].startTime, "[TKMStaking1B][setStaking]: _endTime is under _startTime");
            require(_endTime > block.timestamp, "[TKMStaking1B][setStaking]: _endTime is under now");
            stakings[_stakeId].endTime = _endTime;
            return;
        }

        require(_endTime > block.timestamp, "[TKMStaking1B][setStaking]: _endTime is under now");

        staking storage newStake = stakings[_stakeId];
        newStake.startTime = _startTime;
        newStake.endTime = _endTime;
        newStake.nftAmount = _nftAmount;
    }

    function stake(uint256 _stakeId, uint256[] memory _ids) public whenNotPaused {
        require(true == stakeIds[_stakeId], "[TKMStaking1B][stake]: invalid stake id");

        require(stakings[_stakeId].startTime <= block.timestamp, "[TKMStaking1B][staking]: staking is not started");
        require(stakings[_stakeId].endTime >= block.timestamp, "[TKMStaking1B][staking]: staking is ended");

        require(stakings[_stakeId].nftAmount == _ids.length, "[TKMStaking1B][staking]: not equal nftAmount");

        for (uint256 i = 0; i < stakings[_stakeId].nftAmount; i++) {
            require(TKMNft.ownerOf(_ids[i]) == msg.sender, "[TKMStaking1B][staking]: owner invalid");
        }

        ++stakingIdx;
        for (uint256 i = 0; i < stakings[_stakeId].nftAmount; i++) {
            TKMNft.safeTransferFrom(msg.sender, NftHolder, _ids[i]);
        }

        stakingProgress storage progress = progressing[stakingIdx];
        progress.user = msg.sender;
        progress.stakeId = _stakeId;
        progress.ids = _ids;

        stakedInfoList[_stakeId - 1].nftCount += 3;
        stakedInfoList[_stakeId - 1].walletCount += 1;

        emit Stake(msg.sender, block.number, _stakeId, stakingIdx, _ids);
    }

    function withdraw(uint256 _stakingIdx) public whenNotPaused {
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking1B][withdraw]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking1B][withdraw]: not Owner");

        stakedInfoList[progressing[_stakingIdx].stakeId - 1].nftCount -= 3;
        stakedInfoList[progressing[_stakingIdx].stakeId - 1].walletCount -= 1;

        uint256[] memory ids = progressing[_stakingIdx].ids;
        delete progressing[_stakingIdx];

        for (uint256 i = 0; i < ids.length; i++) {
            TKMNft.safeTransferFrom(NftHolder, msg.sender, ids[i]);
        }

        emit Withdraw(msg.sender, block.number, _stakingIdx);
    }

    // harvest
    function harvest(uint256 _stakingIdx) public whenNotPaused {
        require(progressing[_stakingIdx].user != address(0), "[TKMStaking1B][harvest]: not exist staking data");
        require(progressing[_stakingIdx].user == msg.sender, "[TKMStaking1B][harvest]: not Owner");

        emit Harvest(msg.sender, block.number, _stakingIdx);
    }

    function getIds(uint256 _stakingIdx) public view returns (uint256[] memory ids) {
        return progressing[_stakingIdx].ids;
    }

    function getStakedInfo() public view returns (uint256 blockNumber, stakedInfo[8] memory stakedList) {
        return (block.number, stakedInfoList);
    }
}
