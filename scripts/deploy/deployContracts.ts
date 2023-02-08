import { UniswapWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory";
import { ethers } from "hardhat";
import { EntangleSynthFactory__factory } from "../../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleDEXOnDemand__factory } from "../../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../../typechain-types/factories/contracts/EntangleDEX__factory";
import { Pauser__factory } from "../../typechain-types/factories/contracts/Pauser__factory";
import { BaseSynthChef__factory } from "../../typechain-types/factories/contracts/synth-chefs/BaseSynthChef__factory";
import { EntangleTestBridge__factory } from "../../typechain-types/factories/contracts/bridge/EntangleTestBridge__factory";
import deploySynthChef from "./deploySynthChef";
import deployWrapper from "./deployWrapper";


export default async function deployContracts(
    BRIDGE_ADDR: string,
) {

    console.log("Start deploying protocol contracts");

    const FEE_COLLECTOR = "0x493b11ee518590515b307f852650cb16483573c6";

    let owner = (await ethers.getSigners())[0];

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

    const EntangleTestBridgeFactory = (await ethers.getContractFactory(
        "EntangleTestBridge"
    )) as EntangleTestBridge__factory;
    let bridge = BaseSynthChef__factory.connect(BRIDGE_ADDR, owner);
    /*
        DEPLOY WRAPPER
    */
    let wrapperAddress = await deployWrapper();

    /*
        DEPLOY CHEF
    */
    let {stableAddress, chefAddress, pids} = await deploySynthChef(wrapperAddress, FEE_COLLECTOR);
    let chef = BaseSynthChef__factory.connect(chefAddress, owner);

    /*
        DEPLOY SYNTH FACTORY
    */
    let factory = await SynthFactoryFactory.deploy();
    await factory.deployed();

    /*
        DEPLOY DEX on DEMAND
    */
    let DEXonDemand = await DEXonDemandFactory.deploy(
        factory.address,
        chef.address
    );
    await DEXonDemand.deployed();

    /*
        DEPLOY LANDING
    */
    let lending = await LendingFactory.deploy();
    await lending.deployed();

    /*
        DEPLOY POOL
    */
    let pool = await PoolFactory.deploy();
    await pool.deployed();

    /*
        DEPLOY ENTANGLE DEX
    */
    let idex = await IDEXFactory.deploy(FEE_COLLECTOR);
    await idex.deployed();

    /*
        DEPLOY ROUTER
    */
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

    /*
        DEPLOY PAUSER
    */
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

    /*
        GRANT ROLES
    */
    await (await bridge.grantRole(bridge.ADMIN_ROLE(), router.address)).wait();
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

    await (await lending.authorizeLender(idex.address)).wait()

    console.log("Wrapper:", wrapperAddress);
    console.log("Synth chef:", chef.address);
    console.log("Factory:", factory.address);
    console.log("DEX on demand:", DEXonDemand.address);
    console.log("Router:", router.address);
    console.log("DEX:", idex.address);
    console.log("Pool:", pool.address);
    console.log("Lending:", lending.address);

    return {
        wrapper: wrapperAddress,
        chef: chef.address,
        factory: factory.address,
        DEXonDemand: DEXonDemand.address,
        router: router.address,
        idex: idex.address,
        pool: pool.address,
        lending: lending.address,
        opToken: stableAddress,
        bridge: BRIDGE_ADDR,
        pauser: pauser.address
    };
}
