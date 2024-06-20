// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./interfaces/IUser.sol";
import "./interfaces/IPuff.sol";
import "hardhat/console.sol";

contract Mining is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public puffToken; // PUFF 合约地址
    address public userToken; // user 合约地址
    address public nftToken; // NFT 合约地址

    uint256 public totalPower; // 总算力
    uint256 public updatedAt; // 更新时间
    uint256 public rewardPerTokenStored; // 价格快照
    uint256 public release; // 每秒释放量

    struct User {
        address owner; // 烟杆所有者
        uint256 collected; // 已领取收益
        uint256 reward; // 待领取收益
        uint256 power; // 算力 100算力=1e8
        uint256 rate; // 分成比例 100% = 1e6
        uint256 rewardPerTokenPaid; // 价格快照
    }
    mapping(address => User) public users;

    struct Task {
        bool activated; // 数据是否激活
        address account; // 拥有者
        address dividend; // 烟杆所有者
        uint256 power; // 算力 100算力=1e8
        uint256 rate; // 分成比例 100% = 1e6
        string arweaveHash; // ArweaveHash
    }
    mapping(uint256 => Task) tasks;

    event PuffTokenUpdated(address newAddress, address oldAddress);
    event UserTokenUpdated(address newAddress, address oldAddress);
    event NftTokenUpdated(address newAddress, address oldAddress);
    event PowerUploaded(address account, uint256 taskID);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(address puffToken_) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());

        puffToken = puffToken_;
        release = 2000e18;
    }

    function setPuffToken(address puffToken_) public onlyRole(MANAGER_ROLE) {
        emit PuffTokenUpdated(puffToken_, puffToken);
        puffToken = puffToken_;
    }
    
    function setUserToken(address userToken_) public onlyRole(MANAGER_ROLE) {
        emit UserTokenUpdated(userToken_, userToken);
        userToken = userToken_;
    }

    function setNftToken(address nftToken_) public onlyRole(MANAGER_ROLE) {
        emit NftTokenUpdated(nftToken_, nftToken);
        nftToken = nftToken_;
    }

    // 算力上传
    // account 用户
    // deviceID 设备ID
    // power 算力 100算力=1e8
    // taskID 任务号
    // hash Arweave hash
    function powerUpload(
        address account,
        uint256 power,
        uint256 deviceID,
        uint256 taskID,
        string memory arwaveHash
    ) public onlyRole(OPERATOR_ROLE) updateReward(account) {
        require(account != address(0), "Mining: Invalid account");
        require(!tasks[taskID].activated, "Mining: taskID is activated");
        uint256 nftID = IUser(userToken).deviceToNft(deviceID);
        address owner = IPuff(nftToken).tokenIDToOwner(nftID);
        uint256 rate = IUser(userToken).rates(owner);
        tasks[taskID] = Task(true, account, owner, power, rate, arwaveHash);
        User storage user = users[account];
        totalPower -= user.power;
        totalPower += power;

        user.owner = owner;
        user.power = power;
        user.rate = rate;

        emit PowerUploaded(account, taskID);
    }

    function stop(
        address account
    ) public onlyRole(OPERATOR_ROLE) updateReward(account) {
        User storage user = users[account];
        user.owner = address(0);
        user.power = 0;
        user.rate = 0;

        // emit Stoped(account, taskID);
    }

    function min(uint a, uint b) public pure returns (uint) {
        return a < b ? a : b;
    }

    function getReward(address account) public view returns (uint256) {
        return
            (users[account].power *
                (rewardPerToken() - users[account].rewardPerTokenPaid)) / 1e6;
    }

    function collect() public updateReward(_msgSender()) {
        require(users[_msgSender()].reward > 0, "Mining: No rewards");
        IERC20(puffToken).safeTransfer(
            _msgSender(),
            users[_msgSender()].reward
        );
        users[_msgSender()].reward = 0;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = block.timestamp;
        if (account != address(0)) {
            users[account].reward += getReward(account);
            users[account].rewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalPower == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((block.timestamp - updatedAt) * release * 1e6) /
            totalPower;
    }
}
