import { UniswapWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory";
import { ethers } from "hardhat";
import { EntangleSynthFactory__factory } from "../../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../../typechain-types/factories/contracts/EntangleDEX__factory";
import { UniswapWrapper } from "../../typechain-types/contracts/dex-wrappers/UniswapWrapper";
import { Pauser__factory } from "../../typechain-types/factories/contracts/Pauser__factory";

import hre from "hardhat";
import { ETHSynthChef__factory } from "../../typechain-types/factories/contracts/synth-chefs/ETHSynthChef.sol";
//import config from "../deploy/addresses/teth_addresses.json"
export default async function deploy(
    WETH_ADDR: string,
    STABLE_ADDR: string,
    UNISWAP_ROUTER: string,
    MASTER_CHEF: string,
    BRIDGE_ADDR: string,
    REWARD_TOKEN: string[],
    FAUCET_ADDR: string
) {
    const PID = 0;
    const LP_TOKEN = "0x845838df265dcd2c412a1dc9e959c7d08537f8a2";
    const CURVE_COMPOUND_POOL = "0xa2b47e3d5c44877cca798226b7b8118f9bfb7a56";
    const UNDERLYING_TOKEN_0 = "0x6b175474e89094c44da98b954eedeac495271d0f"; // DAI
    const UNDERLYING_TOKEN_1 = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"; // USDC
    const CONVEX_REWARD = "0xf34DFF761145FF0B05e917811d488B441F33a968";


    let owner = (await ethers.getSigners())[0];
    let chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    const LendingFactory = (await ethers.getContractFactory(
        "EntangleLending"
    )) as EntangleLending__factory;
    const PoolFactory = (await ethers.getContractFactory(
        "EntanglePool"
    )) as EntanglePool__factory;
    const RouterFactory = (await ethers.getContractFactory(
        "EntangleRouter"
    )) as EntangleRouter__factory;
    const UniswapWrapperFactory = (await ethers.getContractFactory(
        "UniswapWrapper"
    )) as UniswapWrapper__factory;
    const ChefFactory = (await ethers.getContractFactory(
        "ETHSynthChef"
    )) as ETHSynthChef__factory;
    const SynthFactoryFactory = (await ethers.getContractFactory(
        "EntangleSynthFactory"
    )) as EntangleSynthFactory__factory;
    const DEXonDemandFactory = (await ethers.getContractFactory(
        "EntangleDEXOnDemand"
    )) as EntangleDEXOnDemand__factory;
    const IDEXFactory = (await ethers.getContractFactory(
        "EntangleDEX"
    )) as EntangleDEX__factory;
    const PauserFactory = (await ethers.getContractFactory(
        "Pauser"
    )) as Pauser__factory;

    let wrapper = (await UniswapWrapperFactory.deploy(
        UNISWAP_ROUTER,
        WETH_ADDR
    )) as UniswapWrapper;
    await wrapper.deployed();

    let chef = await ChefFactory.deploy(
        MASTER_CHEF, //chef
        wrapper.address, //dex interface
        STABLE_ADDR, //stable
        REWARD_TOKEN, //reward
        "1", //fee
        await owner.getAddress()
    ); //fee collector
    await chef.deployed();

    let factory = await SynthFactoryFactory.deploy();
    await factory.deployed();

    let DEXonDemand = await DEXonDemandFactory.deploy(
        factory.address,
        chef.address
    );
    await DEXonDemand.deployed();

    let lending = await LendingFactory.deploy();
    await lending.deployed();

    let pool = await PoolFactory.deploy();
    await pool.deployed();

    let idex = await IDEXFactory.deploy(owner.getAddress());
    await idex.deployed();

    let router = await RouterFactory.deploy(
        pool.address,
        idex.address,
        chef.address,
        factory.address,
        lending.address,
        BRIDGE_ADDR,
        2500,
        4,
        2
    );
    await router.deployed();

    let pauser = await PauserFactory.deploy(
        [
            chef.address,
            factory.address,
            DEXonDemand.address,
            pool.address,
            idex.address,
            router.address,
            lending.address,

        ]);
    await pauser.deployed();
    await (
        await chef.grantRole(chef.ADMIN_ROLE(), await owner.getAddress())
    ).wait();
    await (await chef.grantRole(chef.BORROWER_ROLE(), lending.address)).wait();
    await (await idex.grantRole(idex.ADMIN(), await owner.getAddress())).wait();
    await (await idex.grantRole(idex.BORROWER_ROLE(), lending.address)).wait();
    await (await idex.grantRole(idex.REBALANCER(), router.address)).wait();
    await (await idex.grantRole(idex.BUYER(), router.address)).wait();
    await (
        await router.grantRole(router.ADMIN(), await owner.getAddress())
    ).wait();
    await (
        await lending.grantRole(lending.BORROWER_ROLE(), router.address)
    ).wait();
    await (await pool.grantRole(pool.DEPOSITER_ROLE(), router.address)).wait();
    await (
        await pool.grantRole(pool.DEPOSITER_ROLE(), await owner.getAddress())
    ).wait();
    await (
        await factory.grantRole(factory.MINT_ROLE(), await owner.getAddress())
    ).wait();
    await (
        await DEXonDemand.grantRole(
            DEXonDemand.ADMIN_ROLE(),
            await owner.getAddress()
        )
    ).wait();
    await (await chef.grantRole(chef.ADMIN_ROLE(), DEXonDemand.address)).wait();
    await (await chef.grantRole(chef.ADMIN_ROLE(), router.address)).wait();
    await (
        await factory.grantRole(factory.MINT_ROLE(), DEXonDemand.address)
    ).wait();

    await (await idex.grantRole(idex.PAUSER_ROLE(), pauser.address)).wait();
    await (await idex.grantRole(idex.PAUSER_ROLE(), pauser.address)).wait();
    await (await router.grantRole(router.PAUSER_ROLE(), pauser.address)).wait();
    await (await pool.grantRole(pool.PAUSER_ROLE(), pauser.address)).wait();
    await (await factory.grantRole(factory.PAUSER_ROLE(), pauser.address)).wait();
    await (await lending.grantRole(lending.PAUSER_ROLE(), pauser.address)).wait();
    await (await chef.grantRole(chef.PAUSER_ROLE(), pauser.address)).wait();

    await chef.addPool(
        LP_TOKEN,
        PID,
        UNDERLYING_TOKEN_0,
        UNDERLYING_TOKEN_1,
        CURVE_COMPOUND_POOL,
        CONVEX_REWARD
    );

    await (await lending.authorizeLender(idex.address)).wait()

    console.log("Wrapper:", wrapper.address);
    console.log("Synth chef:", chef.address);
    console.log("Factory:", factory.address);
    console.log("DEX on demand:", DEXonDemand.address);
    console.log("Router:", router.address);
    console.log("DEX:", idex.address);
    console.log("Pool:", pool.address);
    console.log("Lending:", lending.address);

    return {
        wrapper: wrapper.address,
        chef: chef.address,
        factory: factory.address,
        DEXonDemand: DEXonDemand.address,
        router: router.address,
        idex: idex.address,
        pool: pool.address,
        lending: lending.address,
        opToken: STABLE_ADDR,
        bridge: BRIDGE_ADDR,
        pauser: pauser.address,
        faucet: FAUCET_ADDR
    };
}
