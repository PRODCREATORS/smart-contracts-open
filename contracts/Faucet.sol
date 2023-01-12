// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Faucet is AccessControl {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public tokenStorage;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event Deposit(address token, uint256 amount);
    event Send(address to, address token, uint256 amount);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OWNER_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
    }

    function deposit(IERC20 token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        tokenStorage[address(token)] += amount;
        emit Deposit(address(token), amount);
    }

    function send(address to, IERC20 token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(tokenStorage[address(token)] > amount, "Not enought liquidity in storage.");
        token.safeTransfer(to, amount);
        tokenStorage[address(token)] -= amount;
        emit Send(to, address(token), amount);
    }
}
