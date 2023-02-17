// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TKMGameA is Pausable, Ownable {
    ERC721 public TKMNft; // tkm nft
    address public GameHolder; // NFT 보관할 지갑 주소
    address public Remover; // remove 호출할 지갑 주소

    // 마켓 > 게임 전송
    event SendGame(address indexed from, uint256 indexed tokenId);
    // 마켓에서 본인 소유로 이전
    event Withdraw(address indexed from, uint256 indexed tokenId);
    // NFT가 burn 되는 경우 gaming 데이터 삭제
    event Remove(address indexed from, uint256 indexed tokenId);

    /////////////////////////////////////////////////////
    // tokenId => 되돌려줄 지갑
    mapping(uint256 => address) public gaming;

    constructor(address _TKMNft, address _GameHolder, address _Remover) {
        TKMNft = ERC721(payable(_TKMNft));
        GameHolder = _GameHolder;
        Remover = _Remover;
    }

    function setRemover(address _remover) public onlyOwner {
        Remover = _remover;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function sendGame(uint256 _tokenId) public whenNotPaused {
        // 오너 체크
        require(TKMNft.ownerOf(_tokenId) == msg.sender, "[TKMGameA][sendGame]: owner invalid");

        // 게임 홀더로 전송
        TKMNft.safeTransferFrom(msg.sender, GameHolder, _tokenId);

        // 현황 기록
        gaming[_tokenId] = msg.sender;

        emit SendGame(msg.sender, _tokenId);
    }

    function withdraw(uint256 _tokenId) public whenNotPaused {
        // 지갑 주소 체크
        require(gaming[_tokenId] == msg.sender, "[TKMGameA][withdraw]: not exist gaming data");

        // 기록 제거
        delete gaming[_tokenId];

        // nft 돌려주기
        TKMNft.safeTransferFrom(GameHolder, msg.sender, _tokenId);

        emit Withdraw(msg.sender, _tokenId);
    }

    function remove(uint256 _tokenId) public {
        // 지갑 주소 체크
        require(msg.sender == Remover, "[TKMGameA][remove]: Remover invalid");
        require(gaming[_tokenId] != address(0), "[TKMGameA][remove]: not exist gaming data");

        address nftOwner = gaming[_tokenId];

        // 기록 제거
        delete gaming[_tokenId];

        emit Remove(nftOwner, _tokenId);
    }
}
