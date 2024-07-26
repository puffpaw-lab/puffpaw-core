// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./interfaces/IDevice.sol";

contract Puff is
    AccessControlUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable
{
    using SafeERC20 for IERC20;
    using Strings for uint256;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public tokenID;
    string public baseURI;

    address public treasuryToken;
    address public deviceToken;
    address public pffToken;

    struct Info {
        uint256 tier;
        uint256 model;
        uint256 vertion;
    }
    mapping(uint256 => Info) public infos;

    struct Recast {
        uint256 tier;
        uint256 model;
        uint256 price;
    }
    mapping(uint256 => Recast) public recasts;

    struct Rule {
        uint256 probability;
        uint256 price;
        uint8[] modelScope;
    }
    Rule[] public rules;

    mapping(address => uint256) public ownerToTokenID;
    mapping(uint256 => address) public tokenIDToOwner;
    mapping(uint256 => bool) public staking;

    event TreasuryUpdated(address newAddr, address oldAddr);
    event DeviceUpdated(address newAddr, address oldAddr);
    event PffUpdated(address newAddr, address oldAddr);
    event BaseURIUpdated(string newUri, string oldUri);
    event Staked(address account, uint256 tokenid, bool status);
    event RuleUpdate(
        uint256 tier,
        uint256 probability,
        uint256 price,
        uint8[] modelScope
    );
    event Recasted(uint256 tokenId, uint256 tier, uint256 model, uint256 price);
    event Replaced(uint256 tokenId, uint256 tier, uint256 model, uint256 price);
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(address treasuryToken_, address deviceToken_, address pffToken_) public initializer {
        __AccessControl_init();
        __ERC721_init("Puffpaw Genesis", "PUFF");
        __ERC721Enumerable_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());

        treasuryToken = treasuryToken_;
        deviceToken = deviceToken_;
        pffToken = pffToken_;

        uint8[] memory scope = new uint8[](3);
        (scope[0], scope[1], scope[2]) = (1, 2, 3);
        rules.push(Rule(2560, 10e18, scope));
        (scope[0], scope[1], scope[2]) = (2, 3, 4);
        rules.push(Rule(2000, 20e18, scope));
        (scope[0], scope[1], scope[2]) = (3, 4, 5);
        rules.push(Rule(1500, 30e18, scope));
        (scope[0], scope[1], scope[2]) = (4, 5, 6);
        rules.push(Rule(1250, 40e18, scope));
        (scope[0], scope[1], scope[2]) = (5, 6, 1);
        rules.push(Rule(1000, 50e18, scope));
        (scope[0], scope[1], scope[2]) = (6, 1, 2);
        rules.push(Rule(750, 60e18, scope));
        (scope[0], scope[1], scope[2]) = (1, 2, 3);
        rules.push(Rule(500, 70e18, scope));
        (scope[0], scope[1], scope[2]) = (2, 3, 4);
        rules.push(Rule(250, 80e18, scope));
        (scope[0], scope[1], scope[2]) = (3, 4, 5);
        rules.push(Rule(100, 90e18, scope));
        (scope[0], scope[1], scope[2]) = (4, 5, 6);
        rules.push(Rule(60, 100e18, scope));
        (scope[0], scope[1], scope[2]) = (5, 6, 1);
        rules.push(Rule(20, 110e18, scope));
        (scope[0], scope[1], scope[2]) = (6, 1, 2);
        rules.push(Rule(10, 120e18, scope));
    }

    function _increaseBalance(
        address account,
        uint128 value
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            AccessControlUpgradeable,
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        require(staking[tokenId] == false, "PUFF: Staking, non-transferable");
        require(
            IDevice(deviceToken).nftToDevice(tokenId) == 0,
            "PUFF: Binding, non-transferable"
        );
        if (to != address(0)) {
            require(balanceOf(to) == 0, "PUFF: Holding quantity exceeds 1.");
        }
        address from = tokenIDToOwner[tokenId];
        ownerToTokenID[from] = 0;
        ownerToTokenID[to] = tokenId;
        tokenIDToOwner[tokenId] = to;
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, infos[tokenId].tier.toString(), ".json"));
    }

    function getRule(
        uint256 tier
    ) public view returns (uint256, uint256, uint8[] memory) {
        require(
            tier > 0 && tier - 1 < rules.length,
            "PUFF: No such configuration"
        );
        Rule memory r = rules[tier - 1];
        return (r.probability, r.price, r.modelScope);
    }

    function setTreasuryToken(address treasuryToken_) public onlyRole(MANAGER_ROLE) {
        emit TreasuryUpdated(treasuryToken_, treasuryToken);
        treasuryToken = treasuryToken_;
    }

    function setDeviceToken(address deviceToken_) public onlyRole(MANAGER_ROLE) {
        emit DeviceUpdated(deviceToken_, deviceToken);
        deviceToken = deviceToken_;
    }

    function setPffToken(address pffToken_) public onlyRole(MANAGER_ROLE) {
        emit PffUpdated(pffToken_, pffToken);
        pffToken = pffToken_;
    }

    function setBaseURI(string memory baseURI_) public onlyRole(MANAGER_ROLE) {
        emit BaseURIUpdated(baseURI, baseURI_);
        baseURI = baseURI_;
    }

    function addRule(
        uint256 probability_,
        uint256 price_,
        uint8[] memory modelScope_
    ) public onlyRole(MANAGER_ROLE) {
        rules.push(Rule(probability_, price_, modelScope_));
        emit RuleUpdate(rules.length, probability_, price_, modelScope_);
    }

    function setRule(
        uint256 tier,
        uint256 probability_,
        uint256 price_,
        uint8[] memory modelScope_
    ) public onlyRole(MANAGER_ROLE) {
        require(
            tier > 0 && tier - 1 < rules.length,
            "PUFF: No such configuration"
        );
        Rule storage rule = rules[tier - 1];
        rule.probability = probability_;
        rule.price = price_;
        rule.modelScope = modelScope_;
        emit RuleUpdate(tier - 1, probability_, price_, modelScope_);
    }

    function mint(
        address to,
        uint256 model,
        uint256 tier,
        uint256 version
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        tokenID++;
        _mint(to, tokenID);
        infos[tokenID] = Info(model, tier, version);
        return tokenID;
    }

    function recasting(uint256 tokenId) public returns (uint256, uint256, uint256) {
        require(tokenIDToOwner[tokenId] == _msgSender(), "PUFF: NFT error");
        require(rules.length > 0, "PUFF: Tier: Invalid configuration");
        uint256 randNum = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    tokenID,
                    block.prevrandao,
                    _msgSender()
                )
            )
        );
        uint256 r = (randNum % 10000) + 1;
        uint256 d;
        uint256 tier = 1;
        for (uint256 i = rules.length - 1; i >= 0; i--) {
            d += rules[i].probability;
            if (r < d) {
                tier = i + 1;
                break;
            }
            if (i == 0) {
                break;
            }
        }
        recasts[tokenId] = Recast({
            tier: tier,
            model: rules[tier - 1].modelScope[randNum % rules[tier - 1].modelScope.length],
            price: rules[tier - 1].price
        });
        Recast memory recast = recasts[tokenId];
        emit Recasted(tokenId, recast.tier, recast.model, recast.price);
        return (recast.tier, recast.model, recast.price);
    }

    function replace(
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(tokenIDToOwner[tokenId] == _msgSender(), "PUFF: NFT error");
        Recast storage recast = recasts[tokenId];
        IERC20Permit(pffToken).permit(
            _msgSender(),
            address(this),
            recast.price,
            deadline,
            v,
            r,
            s
        );
        IERC20(pffToken).safeTransferFrom(_msgSender(), address(this), recast.price);
        IERC20(pffToken).safeTransfer(treasuryToken, recast.price);
        emit Replaced(tokenId, recast.tier, recast.model, recast.price);
        Info storage info = infos[tokenId];
        info.tier = recast.tier;
        info.model = recast.model;
        recast.tier = 0;
        recast.model = 0;
        recast.price = 0;
    }

    function stake(uint256 tokenId, bool status) public {
        require(tokenIDToOwner[tokenId] == _msgSender(), "PUFF: NFT error");
        emit Staked(_msgSender(), tokenId, status);
        if (status) {
            require(staking[tokenId] == false, "PUFF: Already staked");
            staking[tokenId] = true;
            return;
        }
        require(staking[tokenId], "PUFF: Not currently staked");
        staking[tokenId] = false;
    }
}
