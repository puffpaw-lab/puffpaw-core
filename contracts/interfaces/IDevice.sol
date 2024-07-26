// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDevice {
    function deviceToNft(uint256) external returns (uint256);
    function nftToDevice(uint256) external returns (uint256);
    function rates(address) external returns (uint256);
}