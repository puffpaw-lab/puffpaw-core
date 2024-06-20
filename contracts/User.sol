// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import "./interfaces/IPuff.sol";

contract User is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public nftToken;

    mapping(uint256 => uint256) public nftToDevice; // NFT=>设备号
    mapping(uint256 => uint256) public deviceToNft; // 设备号=>NFT
    mapping(address => uint256) public rates; // 分成比例 100% = 1e6

    event NftUpdated(address newAddress, address oldAddress);
    event Bound(address account, uint256 deviceID, uint256 nftID);
    event UnBound(address account, uint256 deviceID, uint256 nftID);
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {}

    function setNFT(address nftToken_) public {
        require(nftToken_ != address(0), "UserInfo: Invalid nftToken");
        emit NftUpdated(nftToken_, nftToken);
        nftToken = nftToken_;
    }

    function binding(uint256 deviceID) public onlyRole(OPERATOR_ROLE) {
        require(deviceToNft[deviceID] == 0, "UserInfo: Already bound to NFT");
        uint256 nftID = IPuff(nftToken).ownerToTokenID(_msgSender());
        require(nftID != 0, "UserInfo: NFT error");
        require(nftToDevice[nftID] == 0, "UserInfo: Already bound to device");
        deviceToNft[deviceID] = nftID;
        nftToDevice[nftID] = deviceID;
        emit Bound(_msgSender(), deviceID, nftID);
    }

    function unbind(uint256 deviceID) public {
        require(
            deviceToNft[deviceID] != 0,
            "UserInfo: The current device is not bound to an NFT"
        );
        uint256 nftID = deviceToNft[deviceID];
        address owner = IPuff(nftToken).ownerOf(nftID);
        require(owner == _msgSender(), "UserInfo: unbind fail");
        deviceToNft[deviceID] = 0;
        nftToDevice[nftID] = 0;
        emit UnBound(_msgSender(), deviceID, nftID);
    }

    function setRate(uint256 rate) public {
        require(rate <= 1e16,"UserInfo: rate error");
        rates[_msgSender()] = rate;
    }
}
