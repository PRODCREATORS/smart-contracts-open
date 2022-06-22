// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EnUSD is ERC20 {

    constructor () ERC20("EnUSD", "ENUSD") {
        _mint(msg.sender, 200000 * (10 ** uint256(decimals())));
    }
}
