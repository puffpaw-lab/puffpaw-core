// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Treasury is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(address => uint256) public balances;

    event Withdrawed(address account, address token, uint256 amount);
    event WithdrawedETH(address account, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
    }

    function dispostETH() public payable {
        balances[_msgSender()] += msg.value;
    }

    function withdrawETH(uint256 value) public onlyRole(MANAGER_ROLE) {
        require(address(this).balance >= value, "Treasury: Insufficient balance");
        payable(_msgSender()).transfer(value);
        emit WithdrawedETH(_msgSender(), value);
    }

    function withdraw(address token, address to, uint256 amount) public onlyRole(MANAGER_ROLE) {
        require(amount > 0, "Mall: Invalid amount"); 
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawed(to, token, amount);
    }
}