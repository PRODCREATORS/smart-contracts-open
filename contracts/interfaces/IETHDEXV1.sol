// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IETHDEXV1 {
    function buy(uint8 _pid, uint256 _amount) external returns (uint256 amountSynth);

    function sell(uint8 _pid, uint256 _amount) external;

    function synths(uint8) view external returns(Synth memory);

}

struct Synth {
        IERC20 synth;
        uint8 synthDecimals;
        uint256 rate;
        uint8 rateDecimals;
        uint8 pid;
        bool isActive;
        bool crosschain;
    }