// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IUser {
    function deviceToNft(uint256) external returns (uint256);
    function rates(address) external returns (uint256);
}