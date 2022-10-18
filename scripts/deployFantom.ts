import hre from "hardhat";
import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { ethers } from "hardhat";
import { FantomSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/FantomSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../typechain-types/factories/contracts/EntangleDEX__factory";


async function main() {
    const PID = 0;
    const WETH_ADDR = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
    const STABLE_ADDR = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75";
    const BRIDGE_ADDR = "0xB003e75f7E0B5365e814302192E99b4EE08c0DEd";
    let owner = (await ethers.getSigners())[0];
    let chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    const LendingFactory = (await ethers.getContractFactory("EntangleLending")) as EntangleLending__factory;
    const PoolFactory = (await ethers.getContractFactory("EntanglePool")) as EntanglePool__factory;
    const RouterFactory = (await ethers.getContractFactory("EntangleRouter")) as EntangleRouter__factory;
    const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
    const ChefFactory = (await ethers.getContractFactory("FantomSynthChef")) as FantomSynthChef__factory;
    const SynthFactoryFactory = (await ethers.getContractFactory("EntangleSynthFactory")) as EntangleSynthFactory__factory;
    const DEXonDemandFactory = (await ethers.getContractFactory("EntangleDEXOnDemand")) as EntangleDEXOnDemand__factory;
    const IDEXFactory = (await ethers.getContractFactory("EntangleDEX")) as EntangleDEX__factory;

    let wrapper = await UniswapWrapperFactory.deploy("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", WETH_ADDR) as UniswapWrapper;
    await new Promise(f => setTimeout(f, 10000));
    let chef = await ChefFactory.deploy("0x09855B4ef0b9df961ED097EF50172be3e6F13665",
        wrapper.address,
        STABLE_ADDR,
        ["0x5Cc61A78F164885776AA610fb0FE1257df78E59B"],
        "1",
        await owner.getAddress());
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

    await (await chef.addPool("0x40DEa26Dd3a0d549dC5Ecd4522045e8AD02f83FB",
        "0x9ad5E3Fcc5a65D3675139e50C7a20E6f30Fd80A0",
        "0x04068da6c83afcfa0e13ba15a6696662335d5b75",
        "0x049d68029688eabf473097a2fc38ef61633a3c7a",
        true)).wait();

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