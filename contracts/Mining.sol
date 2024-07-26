// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./interfaces/IPuff.sol";
import "./interfaces/ITreasury.sol";

contract Mining is AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public pffToken;
    address public puffToken;
    address public treasuryToken;

    uint256 public totalPower;
    uint256 public updatedAt;
    uint256 public rewardPerTokenStored;
    uint256 public release;
    uint256 public fee;

    struct User {
        address deviceOwner;
        uint256 collected;
        uint256 reward;
        uint256 power;
        uint256 rate;
        uint256 rewardPerTokenPaid;
        uint256 taskID;
        uint256 stopTime;
    }
    mapping(address => User) public users;

    struct Task {
        bool activated;
        address account;
        address deviceOwner;
        uint256 power;
        uint256 rate;
        uint256 reward;
        string arweaveHash;
    }
    mapping(uint256 => Task) public tasks;

    event PffTokenUpdated(address newAddr, address oldAddr);
    event PuffTokenUpdated(address newAddr, address oldAddr);
    event TreasuryTokenUpdated(address newAddr, address oldAddr);
    event FeeUpdated(uint256 newFee, uint256 oldFee);
    event ReleaseUpdated(uint256 newRelease, uint256 oldRelease);
    event PowerUploaded(address account, uint256 taskID);
    event Stoped(address account, uint256 taskID);
    event Collected(address account, uint256 amount);
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(
        address pffToken_,
        address puffToken_,
        address treasuryToken_
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());

        pffToken = pffToken_;
        puffToken = puffToken_;
        treasuryToken = treasuryToken_;
        release = 2000e18;
        fee = 1e4;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = block.timestamp;
        if (account != address(0)) {
            (uint256 reward, uint256 divide) = getReward(account);
            if (account != users[account].deviceOwner) {
                users[users[account].deviceOwner].reward += divide;
            }
            users[account].reward += reward;
            users[account].rewardPerTokenPaid = rewardPerTokenStored;
            if (users[account].taskID != 0) {
                tasks[users[account].taskID].reward += reward + divide;
            }
        }
        _;
    }

    function setPffToken(address pffToken_) public onlyRole(MANAGER_ROLE) {
        emit PffTokenUpdated(pffToken_, pffToken);
        pffToken = pffToken_;
    }

    function setPuffToken(address puffToken_) public onlyRole(MANAGER_ROLE) {
        emit PuffTokenUpdated(puffToken_, puffToken);
        puffToken = puffToken_;
    }

    function setTreasuryToken(
        address treasuryToken_
    ) public onlyRole(MANAGER_ROLE) {
        emit TreasuryTokenUpdated(treasuryToken_, treasuryToken);
        treasuryToken = treasuryToken_;
    }

    function setFee(uint256 fee_) public onlyRole(MANAGER_ROLE) {
        emit FeeUpdated(fee_, fee);
        fee = fee_;
    }

    function setRelease(uint256 dailyRelease) public onlyRole(MANAGER_ROLE) {
        uint256 release_ = dailyRelease / 1 days;
        emit ReleaseUpdated(release_, release);
        release = release_;
    }
    
    function getReward(address account) public view returns (uint256, uint256) {
        uint256 reward = (users[account].power *
            (rewardPerToken() - users[account].rewardPerTokenPaid)) / 1e6;
        uint256 divide;
        if (account != users[account].deviceOwner) {
            divide = (reward * users[account].rate) / 1e6;
            reward -= divide;
        }
        return (reward, divide);
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

    function powerUpload(
        address account,
        address deviceOwner,
        uint256 power,
        uint256 rate,
        uint256 taskID,
        string memory arwaveHash
    ) public onlyRole(OPERATOR_ROLE) updateReward(account) {
        require(account != address(0), "Mining: Invalid account");
        require(IPuff(puffToken).ownerToTokenID(deviceOwner) > 0, "Mining: deviceOwner No NFT");
        require(power > 0, "Mining: power error");
        require(rate < 1e6, "Mining: rate error");
        require(taskID > 0, "Mining: taskID error");
        require(!tasks[taskID].activated, "Mining: taskID is activated");
        tasks[taskID] = Task(
            true,
            account,
            deviceOwner,
            power,
            rate,
            0,
            arwaveHash
        );
        User storage user = users[account];
        totalPower -= user.power;
        totalPower += power;

        user.deviceOwner = deviceOwner;
        user.power = power;
        user.rate = rate;
        if (user.taskID != 0) {
            emit Stoped(account, user.taskID);
        }
        user.taskID = taskID;
        emit PowerUploaded(account, taskID);
    }

    function stop(
        address account
    ) public onlyRole(OPERATOR_ROLE) updateReward(account) {
        User storage user = users[account];
        if(user.taskID != 0) {
            totalPower -= user.power;
            user.deviceOwner = address(0);
            user.power = 0;
            user.rate = 0;
            user.taskID = 0;
            user.stopTime = block.timestamp;
            emit Stoped(account, user.taskID);
        }
    }

    function collect() public updateReward(_msgSender()) {
        uint256 reward = users[_msgSender()].reward;
        require(reward > 0, "Mining: No rewards");
        emit Collected(_msgSender(), reward);
        if (fee > 0) {
            reward -= (reward * fee) / 1e6;
        }
        ITreasury(treasuryToken).withdraw(pffToken, _msgSender(), reward);
        users[_msgSender()].reward = 0;
        users[_msgSender()].collected += reward;
    }
}
