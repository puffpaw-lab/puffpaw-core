// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

contract Pff is AccessControlUpgradeable, ERC20Upgradeable,  ERC20PermitUpgradeable, ERC20BurnableUpgradeable  {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant MAX_MINTED = 100000000000e18;

    uint256 public totalMinted;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __ERC20_init("PUFFPAW","PFF");
        __ERC20Permit_init("PUFFPAW");
        __ERC20Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
    }
    
    function mint(address account, uint256 amount) public onlyRole(MANAGER_ROLE) {
        require(totalMinted+amount <= MAX_MINTED, "Puff: Limit Exceeded");
        super._mint(account, amount);
        totalMinted += amount;
    }
}