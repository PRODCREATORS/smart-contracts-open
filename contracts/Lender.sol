//SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PausableAccessControl.sol";


contract Lender is PausableAccessControl {
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER");

    function borrow(IERC20 token, uint256 amount, address to) onlyRole(BORROWER_ROLE) whenNotPaused public {
        token.transfer(to, amount);
    }
}
