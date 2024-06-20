// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract Mall is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public payToken; // 支付代币地址

    mapping(uint256 => bool) public orderSns; // 订单号

    event Payed(uint256 orderSn, address account, uint256 amount);
    event PayTokenUpdated(address newAddress, address oldAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payToken_) public initializer {
        __AccessControl_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());

        payToken = payToken_;
    }

    function setPayToken(address payToken_) public onlyRole(MANAGER_ROLE) {
        emit PayTokenUpdated(payToken_, payToken);
        payToken = payToken_;
    }

    function pay(
        uint256 orderSn,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(orderSn > 0, "User: Invalid deviceID");
        require(!orderSns[orderSn], "Mall: The order has been paid");
        IERC20Permit(payToken).permit(
            _msgSender(),
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        IERC20(payToken).safeTransferFrom(_msgSender(), address(this), amount);
        orderSns[orderSn] = true;
        emit Payed(orderSn, _msgSender(), amount);
    }
}
