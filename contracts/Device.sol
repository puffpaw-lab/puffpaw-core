// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./interfaces/IPuff.sol";

contract Device is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public puffToken;

    struct DeviceInfo {
        address owner;
        address user;
        uint256 bindTime;
        uint256 rentTime;
        uint256 tokenId;
    }
    mapping(uint256 => DeviceInfo) public devices;

    mapping(uint256 => uint256) public nftToDevice;
    mapping(address => uint256) public userToDevice;

    event PuffTokenUpdated(address newAddr, address oldAddr);
    event Bound(address account, uint256 deviceId, uint256 nftId);
    event UnBound(address account, uint256 deviceId, uint256 nftId);
    event UserUpdated(uint256 deviceId, address account);
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
    }

    function setPuffToken(address puffToken_) public onlyRole(MANAGER_ROLE) {
        require(puffToken_ != address(0), "UserInfo: Invalid nftToken");
        emit PuffTokenUpdated(puffToken_, puffToken);
        puffToken = puffToken_;
    }

    function binding(uint256 tokenId, uint256 deviceId) public {
        require(
            IPuff(puffToken).tokenIDToOwner(tokenId) == _msgSender(),
            "User: NFT error"
        );
        require(nftToDevice[tokenId] == 0, "User: Already bound to device");
        require(
            devices[deviceId].owner == address(0),
            "User: Already bound to NFT"
        );
        require(
            block.timestamp - devices[deviceId].bindTime > 10 minutes,
            "User: Ownership can be changed once every 24 hours"
        );
        nftToDevice[tokenId] = deviceId;
        if (userToDevice[_msgSender()] != 0) {
            _cancelRent(userToDevice[_msgSender()], true);
        }
        userToDevice[_msgSender()] = deviceId;
        devices[deviceId].owner = _msgSender();
        devices[deviceId].user = _msgSender();
        devices[deviceId].bindTime = block.timestamp;
        devices[deviceId].tokenId = tokenId;
        emit Bound(_msgSender(), deviceId, tokenId);
    }

    function unbind(uint256 tokenId, uint256 deviceId) public {
        require(
            IPuff(puffToken).tokenIDToOwner(tokenId) == _msgSender(),
            "User: NFT error"
        );
        require(
            deviceId > 0 && nftToDevice[tokenId] == deviceId,
            "User: deviceId error"
        );
        require(
            block.timestamp - devices[deviceId].bindTime > 10 minutes,
            "User: Ownership can be changed once every 24 hours"
        );
        nftToDevice[tokenId] = 0;
        userToDevice[devices[deviceId].user] = 0;
        devices[deviceId].owner = address(0);
        devices[deviceId].user = address(0);
        devices[deviceId].bindTime = block.timestamp;
        devices[deviceId].rentTime = 0;
        devices[deviceId].tokenId = 0;
        emit UnBound(_msgSender(), deviceId, tokenId);
    }

    function rent(uint256 deviceId) public {
        require(
            devices[deviceId].owner != address(0),
            "User: The device is not bound"
        );
        _rent(deviceId, _msgSender());
    }

    function rentTo(uint256 deviceId, address account) public {
        require(
            devices[deviceId].owner == _msgSender(),
            "User: Not the owner of the device"
        );
        _rent(deviceId, account);
    }

    function rentFrom(
        uint256 deviceId,
        address account
    ) public onlyRole(MANAGER_ROLE) {
        require(
            devices[deviceId].owner != address(0),
            "User: The device is not bound"
        );
        _rent(deviceId, account);
    }

    function _rent(uint256 deviceId, address user) internal {
        require(
            nftToDevice[IPuff(puffToken).ownerToTokenID(user)] == 0,
            "User: Own an device, cannot rent"
        );
        require(
            devices[deviceId].owner != user,
            "User: Can't rent to yourself"
        );
        require(
            devices[deviceId].owner == devices[deviceId].user,
            "User: Devices has been leased"
        );
        require(
            block.timestamp - devices[deviceId].rentTime >= 10 minutes,
            "User: Lease rights can be changed every 24 hours"
        );
        if (userToDevice[user] != 0) {
            _cancelRent(userToDevice[user], false);
        }
        devices[deviceId].rentTime = block.timestamp;
        devices[deviceId].user = user;
        userToDevice[user] = deviceId;
        userToDevice[devices[deviceId].owner] = 0;
        emit UserUpdated(deviceId, user);
    }

    function cancelRent(uint256 deviceId) public {
        require(
            devices[deviceId].user == _msgSender(),
            "User: Not a lessee of device"
        );
        _cancelRent(deviceId, false);
    }

    function cancelRentTo(uint256 deviceId) public {
        require(
            devices[deviceId].owner == _msgSender(),
            "User: Not the owner of the device"
        );
        _cancelRent(deviceId, false);
    }

    function _cancelRent(uint256 deviceId, bool t) internal {
        require(
            devices[deviceId].owner != devices[deviceId].user,
            "User: Devices not leased"
        );
        if (!t) {
            require(
                block.timestamp - devices[deviceId].rentTime > 10 minutes,
                "User: Lease rights can be changed every 24 hours"
            );
        }
        userToDevice[devices[deviceId].owner] = deviceId;
        userToDevice[devices[deviceId].user] = 0;
        devices[deviceId].rentTime = block.timestamp;
        devices[deviceId].user = devices[deviceId].owner;
        emit UserUpdated(deviceId, devices[deviceId].user);
    }
}
