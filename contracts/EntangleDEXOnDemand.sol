// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./EntangleSynthFactory.sol";
import "./EntangleSynth.sol";
import "./synth-chefs/BaseSynthChef.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract EntangleDEXOnDemand is AccessControl {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using SafeERC20 for EntangleSynth;

    EntangleSynth public synth; //synth token
    EntangleSynthFactory public factory; //synth factory
    IERC20Metadata public opToken; //token which will be paid for synth and will be get after selling synth
    BaseSynthChef public chef; //masterchef
    uint256 public pid; // poolID at synth chef

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BUYER = keccak256("BUYER");

    /**
     * @dev Sets the values for `synth`, `pid`,`factory`,`opToken`,`rate` and `chef`.
     */
    constructor(
        uint256 _pid,
        EntangleSynthFactory _factory,
        BaseSynthChef _chef
    ) {
        factory = _factory;
        chef = _chef;
        pid = _pid;
        synth = factory.synths(block.chainid, address(chef), _pid);
        opToken = IERC20Metadata(address(synth.opToken()));

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(BUYER, ADMIN_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);

        opToken.safeIncreaseAllowance(address(chef), type(uint256).max);
        synth.safeIncreaseAllowance(address(chef), type(uint256).max);
    }

    /**
     * @notice Trade function to buy synth token.
     * @param _amount The amount of the source token being traded.
     *
     * Requirements:
     *
     * - the caller must have `BUYER` role.
     */
    function buy(uint256 _amount) external onlyRole(BUYER) {
        uint256 amountSynth = synth.convertOpAmountToSynthAmount(_amount);
        opToken.safeTransferFrom(msg.sender, address(this), _amount);
        chef.deposit(
            pid,
            address(opToken),
            _amount,
            0
        );
        factory.mint(
            block.chainid,
            address(chef),
            pid,
            amountSynth,
            msg.sender
        );
    }

    /**
     * @notice Trade function to sell synth token.
     * @param _amount The amount of the source token being traded.
     *
     * Requirements:
     *
     * - the caller must have `BUYER` role.
     */
    function sell(uint256 _amount) external onlyRole(BUYER) {
        factory.burn(
            block.chainid,
            address(chef),
            pid,
            _amount,
            msg.sender
        );
        chef.withdraw(pid, address(opToken), _amount, msg.sender, 0);
    }
}