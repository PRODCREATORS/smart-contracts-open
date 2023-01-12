import { UniswapWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory";
import { ethers } from "hardhat";
import { EntangleSynthFactory__factory } from "../../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../../typechain-types/factories/contracts/EntangleDEX__factory";
import { FantomSynthChef__factory } from "../../typechain-types/factories/contracts/synth-chefs/FantomSynthChef.sol";
import { UniswapWrapper } from "../../typechain-types/contracts/dex-wrappers/UniswapWrapper";
import { Pauser__factory } from "../../typechain-types/factories/contracts/Pauser__factory";
import { Faucet__factory } from "../../typechain-types/factories/contracts/Faucet__factory";
import hre from "hardhat";
import fs from "fs/promises";
import path from "path";
export default async function main(
    WETH_ADDR: string,
    STABLE_ADDR: string,
    BRIDGE_ADDR: string,
    UNISWAP_ROUTER: string,
    MASTER_CHEF: string,
    REWARD_TOKEN: string
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
    const UniswapWrapperFactory = (await ethers.getContractFactory(
        "UniswapWrapper"
    )) as UniswapWrapper__factory;
    const ChefFactory = (await ethers.getContractFactory(
        "FantomSynthChef"
    )) as FantomSynthChef__factory;
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
    const FaucetFactory = (await ethers.getContractFactory(
        "Faucet"
    )) as Faucet__factory;
    
    let wrapper = (await UniswapWrapperFactory.deploy(
        UNISWAP_ROUTER,
        WETH_ADDR
    )) as UniswapWrapper;
    await wrapper.deployed();
    let chef = await ChefFactory.deploy(
        MASTER_CHEF,
        wrapper.address,
        STABLE_ADDR,
        [REWARD_TOKEN],
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
    let faucet = await FaucetFactory.deploy()
    await faucet.deployed();

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
            "0x364705F8D0744230f39BC176e0270d90dbc72E50",
            "0x9F0FeB56184f28043f8159af4238cE179D97cBA5",
            "0x82f0B8B456c1A451378467398982d4834b6829c1",
            "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
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
    await (await lending.authorizeLender(idex.address)).wait()

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
            opToken: STABLE_ADDR
        })
    );
    // await fs.writeFile(
    //     path.join(
    //         "/",
    //         "Users",
    //         "dexat0r",
    //         "github",
    //         "entangle",
    //         "backend-script",
    //         "src",
    //         "services",
    //         "config",
    //         `${hre.network.name}_addresses.json`
    //     ),
    //     JSON.stringify({
    //         wrapper: wrapper.address,
    //         chef: chef.address,
    //         factory: factory.address,
    //         DEXonDemand: DEXonDemand.address,
    //         router: router.address,
    //         idex: idex.address,
    //         pool: pool.address,
    //         lending: lending.address,
    //     })
    // );

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
