// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILender {
    function borrow(IERC20 token, uint256 amount, address to) external;
}