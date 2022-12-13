// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TKMTokenA is ERC20, Pausable, AccessControl {
    uint256 constant _initial_supply = 1 * 1e9; // 초기 발행 수량. 10 억개

    constructor() ERC20("Three Kingdom Multiverse", "3KM_A") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, _initial_supply * (10**uint256(decimals())));
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
