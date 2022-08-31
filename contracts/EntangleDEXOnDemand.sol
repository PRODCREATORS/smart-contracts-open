//SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./EntangleSynthFactory.sol";
import "./EntangleSynth.sol";
import "./interfaces/ISynthChef.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract EntangleDEXOnDemand is AccessControl {
    using SafeMath for uint256;

    EntangleSynth public synth; //synth token
    EntangleSynthFactory public factory; //synth factory
    IERC20Metadata public opToken; //token which will be paid for synth and will be get after selling synth
    ISynthChef public chef; //masterchef
    uint256 public poolID; // poolID at synth chef

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BUYER = keccak256("BUYER");

    /**
     * @dev Sets the values for `synth`, `pid`,`factory`,`opToken`,`rate` and `chef`.
     */
    constructor(
        uint256 _synth,
        uint256 _poolID,
        EntangleSynthFactory _factory,
        ISynthChef _chef
    ) {
        factory = _factory;
        poolID = _poolID;
        synth = EntangleSynth(factory.getSynth(_synth));
        opToken = IERC20Metadata(address(synth.opToken()));
        chef = _chef;

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(BUYER, ADMIN_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);

        opToken.approve(address(chef), type(uint256).max);
        synth.approve(address(chef), type(uint256).max);
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
        opToken.transferFrom(msg.sender, address(this), _amount);
        chef.deposit(
            _amount,
            address(opToken),
            poolID
        );
        factory.mint(
            synth.pid(),
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
        uint256 amountOpToken = synth.convertSynthAmountToOpAmount(_amount);
        factory.burn(
            synth.pid(),
            msg.sender,
            _amount
        );
        uint256 lpAmount = amountOpToken * (10 ** 18) / synth.getPriceFor1LP();
        chef.withdraw(lpAmount, address(opToken), msg.sender, poolID);
    }
}