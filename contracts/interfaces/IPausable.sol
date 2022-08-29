// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IPausable {
    function pause() external;
    function unpause() external;
}