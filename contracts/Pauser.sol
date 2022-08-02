// SPDX-License-Identifier: MIT ddd
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interfaces/IPausable.sol";


contract Pauser is AccessControlEnumerable {
    IPausable[] public contracts;

    bytes32 public constant ADMIN_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(IPausable[] memory _contracts) {
        contracts = _contracts;
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function pause() onlyRole(PAUSER_ROLE) external {
        IPausable[] memory _contracts = contracts;
        for (uint256 i = 0; i < _contracts.length; i++) {
            _contracts[i].pause();
        }
    }

    function unpause() onlyRole(PAUSER_ROLE) external {
        IPausable[] memory _contracts = contracts;
        for (uint256 i = 0; i < _contracts.length; i++) {
            _contracts[i].unpause();
        }
    }
}

