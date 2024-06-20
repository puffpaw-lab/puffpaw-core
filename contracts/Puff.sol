// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

contract Puff is
    AccessControlUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public tokenID;
    
    address public Treasury; // 资金合约
    address public Staking; // 质押合约

    struct Info {
        uint256 tier; // 稀有度
        uint256 model; // 加成烟弹 1=A，2=B ... 6=F
        uint256 vertion; // 版本，代数：第一代NFT、第二代NFT
    }
    mapping(uint256 => Info) public infos;

    struct Recast {
        uint256 tier; // 稀有度
        uint256 model; // 加成烟弹 1=A，2=B ... 6=F
    }
    mapping(uint256 => Recast) public recasts;

    struct Rule {
        uint256 probability;
        uint256 price;
    }
    Rule[] public rules; // 重铸概率及价格

    mapping(address => uint256) public ownerToTokenID; // 根据用户查询NFTID
    mapping(uint256 => address) public tokenIDToOwner; // 根据NFTID查询用户

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        __ERC721_init("Puffpaw Genesis", "PUFF");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());

        rules.push(Rule(2560, 10e18));
        rules.push(Rule(2000, 20e18));
        rules.push(Rule(1500, 30e18));
        rules.push(Rule(1250, 40e18));
        rules.push(Rule(1000, 50e18));
        rules.push(Rule(750, 60e18));
        rules.push(Rule(500, 70e18));
        rules.push(Rule(250, 80e18));
        rules.push(Rule(100, 90e18));
        rules.push(Rule(60, 100e18));
        rules.push(Rule(20, 110e18));
        rules.push(Rule(10, 120e18));
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

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable
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
        if(_ownerOf(tokenId) != Staking && to != Staking){
            ownerToTokenID[to] = tokenID;
            tokenIDToOwner[tokenID] = to;
        }
        return super._update(to, tokenId, auth);
    }

    // function _transfer(from, to, tokenId) public override {
    //     super._transfer(from, to, tokenId);
    // }

    function mint(
        address to,
        string memory tokenUri,
        uint256 model,
        uint256 tier,
        uint256 version
    ) public onlyRole(MANAGER_ROLE) returns (uint256) {
        require(balanceOf(to) == 0, "NFT: Already own NFT");
        tokenID++;
        _mint(to, tokenID);
        _setTokenURI(tokenID, tokenUri);
        infos[tokenID] = Info(model, tier, version);
        return tokenID;
    }

    // 重铸
    function recast(uint256 _tokenID) public returns (uint256, uint256) {
        address owner = ownerOf(_tokenID);
        require(owner != address(0), "NFT: Invalid tokenID");
        uint256 randNum = (uint256(keccak256(abi.encodePacked(block.timestamp, tokenID, block.prevrandao, _msgSender()))) % 10000) + 1;
        uint256 d;
        for(uint256 i = rules.length - 1; i >= 0 ; i--){
            d += rules[i].probability;
            if(randNum < rules[i].probability){
                recasts[_tokenID].tier = i + 1;
                continue;
            }
        }
        recasts[_tokenID].model = (uint256(keccak256(abi.encodePacked(block.timestamp, tokenID, block.prevrandao, _msgSender()))) % 3) + 1;
        return (recasts[_tokenID].tier, recasts[_tokenID].model);
    }
}
