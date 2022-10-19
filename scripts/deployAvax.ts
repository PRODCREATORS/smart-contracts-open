import hre from "hardhat";
import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { ethers } from "hardhat";
import { AvaxSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/AvaxSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../typechain-types/factories/contracts/EntangleDEX__factory";


async function main() {
    const PID = 51;
    const WETH_ADDR = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    const STABLE_ADDR = "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E";
    const BRIDGE_ADDR = "0x0EF812f4c68DC84c22A4821EF30ba2ffAB9C2f3A";
    let owner = (await ethers.getSigners())[0];
    let chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    const LendingFactory = (await ethers.getContractFactory("EntangleLending")) as EntangleLending__factory;
    const PoolFactory = (await ethers.getContractFactory("EntanglePool")) as EntanglePool__factory;
    const RouterFactory = (await ethers.getContractFactory("EntangleRouter")) as EntangleRouter__factory;
    const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
    const ChefFactory = (await ethers.getContractFactory("AvaxSynthChef")) as AvaxSynthChef__factory;
    const SynthFactoryFactory = (await ethers.getContractFactory("EntangleSynthFactory")) as EntangleSynthFactory__factory;
    const DEXonDemandFactory = (await ethers.getContractFactory("EntangleDEXOnDemand")) as EntangleDEXOnDemand__factory;
    const IDEXFactory = (await ethers.getContractFactory("EntangleDEX")) as EntangleDEX__factory;

    let wrapper = await UniswapWrapperFactory.deploy("0x60aE616a2155Ee3d9A68541Ba4544862310933d4", WETH_ADDR) as UniswapWrapper;
    await new Promise(f => setTimeout(f, 10000));
    let chef = await ChefFactory.deploy("0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00", //chef
            "0x60aE616a2155Ee3d9A68541Ba4544862310933d4", //router
        wrapper.address, //dex interface
        STABLE_ADDR, //stable
        ["0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd"], //reward
        "1", //fee
        await owner .getAddress()); //fee collector
    await new Promise(f => setTimeout(f, 10000));
    let factory = await SynthFactoryFactory.deploy();
    await new Promise(f => setTimeout(f, 10000));
    let DEXonDemand = await DEXonDemandFactory.deploy(factory.address, chef.address);
    await new Promise(f => setTimeout(f, 10000));
    let lending = await LendingFactory.deploy();
    await new Promise(f => setTimeout(f, 10000));
    let pool = await PoolFactory.deploy();
    await new Promise(f => setTimeout(f, 10000));
    let idex = await IDEXFactory.deploy(owner.getAddress());
    await new Promise(f => setTimeout(f, 10000));
    let router = await RouterFactory.deploy(pool.address, idex.address, chef.address, factory.address, lending.address, BRIDGE_ADDR);
    await new Promise(f => setTimeout(f, 10000));

    await (await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress())).wait();
    await (await chef.grantRole(chef.BORROWER_ROLE(), lending.address)).wait();
    await (await idex.grantRole(idex.ADMIN(), owner.getAddress())).wait();
    await (await idex.grantRole(idex.BORROWER_ROLE(), lending.address)).wait();
    await (await router.grantRole(router.ADMIN(), owner.getAddress())).wait();
    await (await lending.grantRole(lending.BORROWER_ROLE(), router.address)).wait();
    await (await pool.grantRole(pool.DEPOSITER_ROLE(), router.address)).wait();
    await (await pool.grantRole(pool.DEPOSITER_ROLE(), owner.getAddress())).wait();
    await (await factory.grantRole(factory.MINT_ROLE(), owner.getAddress())).wait();
    await (await DEXonDemand.grantRole(DEXonDemand.ADMIN_ROLE(), owner.getAddress())).wait();
    await (await DEXonDemand.grantRole(DEXonDemand.BUYER(), owner.getAddress())).wait();
    await (await chef.grantRole(chef.ADMIN_ROLE(), DEXonDemand.address)).wait();
    await (await chef.grantRole(chef.ADMIN_ROLE(), router.address)).wait();
    await (await factory.grantRole(factory.MINT_ROLE(), DEXonDemand.address)).wait();


    let addr = await factory.previewSynthAddress(chainId, chef.address, PID, STABLE_ADDR);
    await (await factory.createSynth(chainId, chef.address, PID, STABLE_ADDR)).wait();
    let synth = EntangleSynth__factory.connect(addr, owner);
    await (await synth.setPrice("2000000")).wait();

    await (await idex.add(synth.address)).wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});