// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;


interface IEntangleDEXWrapper {
    function convert(address from, address to, uint256 amount) external  returns(uint256);

    function previewConvert(address from, address to, uint256 amount) external view returns(uint256);
}