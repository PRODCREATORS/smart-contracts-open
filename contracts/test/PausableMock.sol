// SPDX-License-Identifier: MIT ddd
pragma solidity ^0.8.10;

import "../PausableAccessControl.sol";

contract PausableMock is PausableAccessControl {
    function addPauser(address _account) external {
        _grantRole(PAUSER_ROLE, _account);
    }
}