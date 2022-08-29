//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IDEX {
    function synth() external view returns (address); 
    function opToken() external view returns (address);
    function buy(uint256) external;
    function sell(uint256) external;
}