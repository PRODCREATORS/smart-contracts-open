import hre from "hardhat";
import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { ethers } from "hardhat";
import { BSCSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/BSCSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleRouter__factory } from "../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntangleLending__factory } from "../typechain-types/factories/contracts/EntangleLending__factory";
import { EntanglePool__factory } from "../typechain-types/factories/contracts/EntanglePool__factory";
import { EntangleDEX__factory } from "../typechain-types/factories/contracts/EntangleDEX__factory";


async function main() {
    const PID = 7;
    const WETH_ADDR = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
    const STABLE_ADDR = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d";
    const BRIDGE_ADDR = "0x749F37Df06A99D6A8E065dd065f8cF947ca23697";
    const UNISWAP_ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    let owner = (await ethers.getSigners())[0];
    let chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    const LendingFactory = (await ethers.getContractFactory("EntangleLending")) as EntangleLending__factory;
    const PoolFactory = (await ethers.getContractFactory("EntanglePool")) as EntanglePool__factory;
    const RouterFactory = (await ethers.getContractFactory("EntangleRouter")) as EntangleRouter__factory;
    const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
    const ChefFactory = (await ethers.getContractFactory("BSCSynthChef")) as BSCSynthChef__factory;
    const SynthFactoryFactory = (await ethers.getContractFactory("EntangleSynthFactory")) as EntangleSynthFactory__factory;
    const DEXonDemandFactory = (await ethers.getContractFactory("EntangleDEXOnDemand")) as EntangleDEXOnDemand__factory;
    const IDEXFactory = (await ethers.getContractFactory("EntangleDEX")) as EntangleDEX__factory;

    let wrapper = UniswapWrapperFactory.attach("0x417fE8A5AD07Cb9A0795E5b35af4ff8400CA4A80");
    
    let chef = ChefFactory.attach("0xcC7BF40513Ff55C0Fc3811F116f58fEE0c201737");

    let factory = SynthFactoryFactory.attach("0x1E07aba46216C032E2Cea0771C14A9a1F7e711D8");

    let DEXonDemand = DEXonDemandFactory.attach("0xe4Ba9D99139FAA768f0D647A9970EE98f0fE7876");
    let lending = LendingFactory.attach("0xEF41D8901427ddE4367298AcCbb7818adf5b5938");
    let pool = PoolFactory.attach("0x4ddf5e8A44670333FdCFF76b5ff863Ac30738767");
    let idex = IDEXFactory.attach("0x743e593eCA668dab9886d25BAE6A957545b9eB5D");
    let router = await RouterFactory.deploy(pool.address, idex.address, chef.address, factory.address, lending.address, BRIDGE_ADDR);

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
    await (await synth.setPrice("10000000")).wait();

    await (await idex.add(synth.address)).wait();

    console.log("Wrapper:", wrapper.address);
    console.log("Synth chef:", chef.address);
    console.log("Factory:", factory.address);
    console.log("DEX on demand:", DEXonDemand.address);
    console.log("Router:", router.address);
    console.log("DEX:", idex.address);
    console.log("Pool:", pool.address);
    console.log("Lending:", lending.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});