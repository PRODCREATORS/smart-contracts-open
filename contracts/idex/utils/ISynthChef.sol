//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ISynthChef {
    function deposit(
        uint256 _pid,
        uint256 _synthPid,
        uint256 _amount,
        address _token
    ) external;

    function withdraw(
        uint256 _pid,
        uint256 _synthPid,
        uint256 _amount,
        address _toToken,
        address payable _to
    ) external;

    function convertStableToLp(uint256 _pid, uint256 _amount)
        external
        view
        returns (uint256);
}
