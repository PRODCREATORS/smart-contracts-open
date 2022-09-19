//SPDX-License-Identifier: BSL 1.1

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Lender.sol";
import "./PausableAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pool is PausableAccessControl {
    struct AnycallInfo {
        uint256 opId;
    }

    using SafeERC20 for IERC20;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant DEPOSITER_ROLE = keccak256("DEPOSITER");
    bytes32 public constant EXEC_CALLER_ROLE = keccak256("EXEC_CALLER_ROLE");

    IERC20 token;
    mapping(address => bool) public canCallExec;

    constructor(IERC20 _token, address _multichainExecutor) {
        _setRoleAdmin(DEPOSITER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXEC_CALLER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        token = _token;
    }
    
    event Deposit(uint256 amount, uint256 opId);
    event Withdraw(uint256 amount);

    function depositToken(uint256 amount, uint256 opId) external onlyRole(DEPOSITER_ROLE) whenNotPaused {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(amount, opId);
    }

    function withdrawToken(uint256 amount, address to) external onlyRole(DEPOSITER_ROLE) whenNotPaused {
        token.safeTransfer(to, amount);
        emit Withdraw(amount);
    }

    function addDepositer(address _depositer) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(hasRole(keccak256("ADMIN"), _depositer) && hasRole(keccak256("DEPOSITER"), _depositer), "you have role");
        grantRole(DEPOSITER_ROLE, _depositer);
    }

    function removeDepositer(address _depositer) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(hasRole(keccak256("ADMIN"), _depositer) && hasRole(keccak256("DEPOSITER"), _depositer), "you have role");
        revokeRole(DEPOSITER_ROLE, _depositer);
	}
    
    function updateToken(IERC20 _token) external onlyRole(ADMIN_ROLE) whenNotPaused {
        token = _token;
    }

    function exec(
        address token,
        address receiver,
        uint256 amount,
        bytes calldata data
    ) onlyRole(EXEC_CALLER_ROLE) {
        AnycallInfo memory info = abi.decode(data, (AnycallInfo));
        emit Deposit(amount, info.opId);
    }
}