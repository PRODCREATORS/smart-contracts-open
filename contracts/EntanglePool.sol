//SPDX-License-Identifier: BSL 1.1

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Lender.sol";
import "./PausableAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/EntangleData.sol";

contract EntanglePool is PausableAccessControl {
    struct AnycallInfo {
        uint256 opId;
    }

    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant DEPOSITER_ROLE = keccak256("DEPOSITER");
    bytes32 public constant EXEC_CALLER_ROLE = keccak256("EXEC_CALLER_ROLE");


    constructor(address _multichainExecutor) {
        _setRoleAdmin(DEPOSITER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXEC_CALLER_ROLE, ADMIN_ROLE);
        _setupRole(EXEC_CALLER_ROLE, _multichainExecutor);
        _setupRole(ADMIN_ROLE, msg.sender);
    }
    
    event Deposit(uint256 amount, address token, uint256 opId);
    event Withdraw(uint256 amount, address token);

    function depositToken(uint256 amount, IERC20 token, uint256 opId) external onlyRole(DEPOSITER_ROLE) whenNotPaused {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(amount, address(token), opId);
    }

    function withdrawToken(uint256 amount, IERC20 token, address to) external onlyRole(DEPOSITER_ROLE) whenNotPaused {
        token.safeTransfer(to, amount);
        emit Withdraw(amount, address(token));
    }

    function exec(
        address receivedToken,
        address receiver,
        uint256 amount,
        bytes calldata encodedData
    ) onlyRole(EXEC_CALLER_ROLE) external {
        EntagleData.Data memory data = abi.decode(encodedData, (EntagleData.Data));
        emit Deposit(amount, receivedToken, data.opId);
    }
}