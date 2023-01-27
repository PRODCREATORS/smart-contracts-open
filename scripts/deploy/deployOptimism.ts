import { ethers } from "hardhat";
import { EntangleSynthFactory__factory } from "../../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../../typechain-types/factories/contracts/EntangleDEX__factory";
import hre from "hardhat";
import fs from "fs/promises";
import path from "path";
import { OptimismSynthChef__factory } from "../../typechain-types/factories/contracts/synth-chefs/OptimismSynthChef.sol/OptimismSynthChef__factory";
import { VelodromeWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/VelodromeWrapper.sol";
import { VelodromeWrapper } from "../../typechain-types/contracts/dex-wrappers/VelodromeWrapper.sol/VelodromeWrapper";
import { Pauser__factory } from "../../typechain-types/factories/contracts/Pauser__factory";

export default async function main(
    STABLE_ADDR: string,
    BRIDGE_ADDR: string,
    UNISWAP_ROUTER: string,
    REWARD_TOKEN: string[],
    FAUCET_ADDR: string
) {
    const PID = 0;

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
    const WrapperFactory = (await ethers.getContractFactory(
        "VelodromeWrapper"
    )) as VelodromeWrapper__factory;
    const ChefFactory = (await ethers.getContractFactory(
        "OptimismSynthChef"
    )) as OptimismSynthChef__factory;
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

    let wrapper = (await WrapperFactory.deploy(
        UNISWAP_ROUTER
    )) as VelodromeWrapper;
    await wrapper.deployed();
    let chef = await ChefFactory.deploy(
        UNISWAP_ROUTER,
        wrapper.address,
        STABLE_ADDR,
        REWARD_TOKEN,
        "1",
        await owner.getAddress()
    );
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

    let idex = await IDEXFactory.deploy(await owner.getAddress());
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

        ]
        );
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

    await (
        await chef.addPool(
            "0xd16232ad60188b68076a235c65d692090caba155",
            "0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80",
            "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
            "0x8c6f28f2f1a3c87f0f938b96d27520d9751ec8d9",
            true
        )
    ).wait();

    let addr = await factory.previewSynthAddress(
        chainId,
        chef.address,
        PID,
        STABLE_ADDR
    );
    await (
        await factory.createSynth(chainId, chef.address, PID, STABLE_ADDR)
    ).wait();
    let synth = EntangleSynth__factory.connect(addr, owner);
    await (await synth.setPrice(BigInt("2000000000000000000"))).wait();

    await (await idex.add(synth.address)).wait();
    await (await lending.authorizeLender(idex.address)).wait();

    console.log("Wrapper:", wrapper.address);
    console.log("Synth chef:", chef.address);
    console.log("Factory:", factory.address);
    console.log("DEX on demand:", DEXonDemand.address);
    console.log("Router:", router.address);
    console.log("DEX:", idex.address);
    console.log("Pool:", pool.address);
    console.log("Lending:", lending.address);

    await fs.writeFile(
        path.join(__dirname, "addresses", `${hre.network.name}_addresses.json`),
        JSON.stringify({
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
        })
    );

    return {
        wrapper: wrapper.address,
        chef: chef.address,
        factory: factory.address,
        DEXonDemand: DEXonDemand.address,
        router: router.address,
        idex: idex.address,
        pool: pool.address,
        lending: lending.address,
    };
}
