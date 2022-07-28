//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Pool is AccessControl, Pausable  {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant DEPOSITER_ROLE = keccak256("DEPOSITER");

    IERC20 token;

    constructor(address _token) {
        _setRoleAdmin(DEPOSITER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        token = IERC20(_token);
    }
    
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    function depositToken( uint256 amount) external onlyRole(DEPOSITER_ROLE) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Deposit(amount);
    }

    function withdrawToken(uint256 amount) external onlyRole(DEPOSITER_ROLE) {
        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(amount);
    }

    function addDepositer(address _depositer) external onlyRole(ADMIN_ROLE) {
        require(hasRole(keccak256("ADMIN"), _depositer) && hasRole(keccak256("DEPOSITER"), _depositer), "you have role");
        grantRole(DEPOSITER_ROLE, _depositer);
    }

    function removeDepositer(address _depositer) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(hasRole(keccak256("ADMIN"), _depositer) && hasRole(keccak256("DEPOSITER"), _depositer), "you have role");
        revokeRole(DEPOSITER_ROLE, _depositer);
    }

    function pause() external whenNotPaused onlyRole(ADMIN_ROLE) {
		_pause();
	}

	function unpause() external whenPaused onlyRole(ADMIN_ROLE) {
		_unpause();
	}
    
    function updateToken(address _token) external onlyRole(ADMIN_ROLE) {
        token = IERC20(_token);
    }
}