//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./idex/ethSynth/ETHSynthFactoryV1.sol";
import "./idex/ethSynth/ETHSynthChefV1.sol";
import "./idex/ethSynth/ETHDEXV1.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Lending.sol";
import "./Pool.sol";

contract Deployer is AccessControl {
    address public admin;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        admin = msg.sender;
    }

    function deploySynthFactory()
        internal
        returns (ETHSynthFactoryV1 synthFactory)
    {
        synthFactory = new ETHSynthFactoryV1();
    }

    function deployPool(IERC20 token) internal returns (Pool pool) {
        pool = new Pool(token);
    }

    function deployLending() internal returns (Lending lending) {
        lending = new Lending();
    }

    function deployChef(
        address router,
        address factory,
        address convex,
        uint256 fee,
        address treasury,
        address rewardToken
    ) internal returns (ETHSynthChefV1 chef) {
        chef = new ETHSynthChefV1(
            router,
            factory,
            convex,
            fee,
            treasury,
            rewardToken
        );
    }

    function deployIDEX(
        address opToken,
        address synthFactory,
        address chef,
        uint8 farmPid,
        address feeCollector
    ) internal returns (ETHDEXV1 idex) {
        idex = new ETHDEXV1(opToken, synthFactory, chef, farmPid, feeCollector);
    }

    function deploy(
        address opToken,
        address router,
        address factory,
        address convex,
        uint256 fee,
        address treasury,
        address rewardToken,
        uint8 farmPid,
        address feeCollector
    ) external onlyRole(ADMIN_ROLE) {
        ETHSynthFactoryV1 synthFactory = deploySynthFactory();
        synthFactory.grantRole(synthFactory.ADMIN_ROLE(), admin);

        Lending lending = deployLending();
        lending.grantRole(lending.ADMIN_ROLE(), admin);

        Pool pool = deployPool(IERC20(opToken));
        pool.grantRole(pool.ADMIN_ROLE(), admin);

        ETHSynthChefV1 chef = deployChef(
            router,
            factory,
            convex,
            fee,
            treasury,
            rewardToken
        );
        chef.grantRole(chef.ADMIN_ROLE(), admin);
        chef.grantRole(chef.BORROWER_ROLE(), address(lending));

        ETHDEXV1 idex = deployIDEX(opToken, address(synthFactory), address(chef), farmPid, feeCollector);
        idex.grantRole(idex.ADMIN(), admin);
        idex.grantRole(idex.BORROWER_ROLE(), address(lending));
    }
}
