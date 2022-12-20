// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EntTestBridge is AccessControl {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public tokenStorage;
    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);

    // synapse bridge events
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenMintAndSwap(
        address indexed to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    function deposit(IERC20 token, uint256 amount) external onlyRole(ADMIN) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        tokenStorage[token] += amount;
        emit Deposit(token, amount);
    }

    function withdraw(IERC20 token, uint256 amount) external onlyRole(ADMIN) {
        require(tokenStorage[token] >= amount, "Not enought liquidity");
        token.safeTransferFrom(address(this), msg.sender, amount);
        tokenStorage[token] -= amount;
        emit Withdraw(token, amount);
    }

    // synapse bridge function emu
    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external onlyRole(ADMIN) {
        token.safeTransferFrom(msg.sender, address(this), amount)
        tokenStorage[token] += amount;

        emit TokenRedeemAndSwap(to,
                chainId,
                token,
                amount,
                tokenIndexFrom,
                tokenIndexTo,
                minDy,
                deadline);
    }

    function SwapTo(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external onlyRole(ADMIN) {

        require(tokenStorage[token] >= amount, "Not enought liquidity");
        token.safeTransferFrom(address(this), to, amount);
        tokenStorage[token] -= amount;

        emit TokenMintAndSwap(to,
                token,
                amount,
                fee,
                tokenIndexFrom,
                tokenIndexTo,
                minDy,
                deadline,
                true,
                0x00);
    }

}