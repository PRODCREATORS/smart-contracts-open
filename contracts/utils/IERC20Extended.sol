// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
    Extended IERC20 interface with decimals() function available
*/
interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}