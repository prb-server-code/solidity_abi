// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Owner.sol";

contract TKMDtcA is ERC20, Owner {
    uint256 constant _initial_supply = 1 * 1e9; // 초기 발행 수량. 10 억개

    constructor() ERC20("Three Kingdom Multiverse Utility Token", "DTC_A") {
        _mint(msg.sender, _initial_supply * (10**uint256(decimals())));
    }
}
