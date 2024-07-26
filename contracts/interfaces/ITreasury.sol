// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ITreasury {
    function withdraw(address token, address to, uint256 amount) external;
}
