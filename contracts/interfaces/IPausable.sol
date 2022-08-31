// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.10;

interface IPausable {
    function pause() external;
    function unpause() external;
}