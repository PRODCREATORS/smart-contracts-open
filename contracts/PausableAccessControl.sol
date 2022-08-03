// SPDX-License-Identifier: MIT ddd
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";


contract PausableAccessControl is AccessControlEnumerable, Pausable  {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function pause() onlyRole(PAUSER_ROLE) external {
        _pause();
    }

    function unpause() onlyRole(PAUSER_ROLE) external {
        _unpause();
    }
}

