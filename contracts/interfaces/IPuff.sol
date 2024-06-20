// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPuff is IERC721 {
    function ownerToTokenID(address) external returns (uint256);
    function tokenIDToOwner(uint256) external returns (address);
}