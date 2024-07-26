// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IPuff{
    function ownerToTokenID(address) external returns (uint256);
    function tokenIDToOwner(uint256) external returns (address);
    function mint(
        address,
        string memory,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);
}
