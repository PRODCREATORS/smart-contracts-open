//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./idex/ethSynth/ETHSynthFactoryV1.sol";
import "./idex/ethSynth/ETHSynthChefV1.sol";
import "./idex/ethSynth/ETHDEXV1.sol";
import "./Lending.sol";
import "./Pool.sol";

interface Ifactory {
    function getSynth(uint256) external view returns (address);
}

contract Deployer is AccessControl {
    address public admin;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        admin = msg.sender;
    }

    function deploy(
        address opToken,
        address rewardToken,
        address convex,
        address router,
        uint256 fee,
        address treasury,
        address rewardToken
    ) external onlyRole(ADMIN_ROLE) {
        ETHSynthFactoryV1 factory = new ETHSynthFactoryV1();
        factory.grantRole(factory.ADMIN_ROLE, admin);

        Lending lending = new Lending(factory);
        lending.grantRole(lending.ADMIN_ROLE, admin);

        Pool pool = new Pool(opToken);
        pool.grantRole(pool.ADMIN_ROLE, admin);

        ETHSynthChefV1 chef = new ETHSynthChefV1(
            router,
            factory,
            convex,
            fee,
            treasury,
            rewardToken
        );
        chef.grantRole(chef.OWNER, admin);

        ETHDEXV1 dex = new ETHDEXV1(opToken, factory, chef, farmPid);
        dex.grantRole(dex.OWNER, admin);
    }
}
