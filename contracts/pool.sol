//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool is AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant DEPOSITER_ROLE = keccak256("DEPOSITER");

    IERC20 token;

    uint256 public amountDeposit;

    constructor(address _token) {
        _setRoleAdmin(DEPOSITER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        token = IERC20(_token);
    }
    
    event deposit(uint256 amount);
    event withdraw(uint256 amount);

    function depositToken( uint256 amount) external onlyRole(DEPOSITER_ROLE) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        amountDeposit += amount;
        emit deposit(amount);
    }

    function withdrawToken(uint256 amount) external onlyRole(DEPOSITER_ROLE) {
        amountDeposit -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit withdraw(amount);
    }

    function addBorrower(address _depositer) external onlyRole(ADMIN_ROLE) {
        grantRole(DEPOSITER_ROLE, _depositer);
    }

}