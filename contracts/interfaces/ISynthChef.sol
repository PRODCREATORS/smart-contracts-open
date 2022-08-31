// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

interface ISynthChef {
    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) external;

    function withdraw(
        uint256 _amount,
        address _toToken,
        address _to,
        uint256 _poolID
    ) external;
}