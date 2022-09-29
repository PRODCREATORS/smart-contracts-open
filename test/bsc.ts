import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { ethers } from "hardhat";
import { BSCSynthChef,} from '../typechain-types/contracts/synth-chefs/BSCSynthChef.sol';
import { BSCSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/BSCSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleSynthFactory } from '../typechain-types/contracts/EntangleSynthFactory';
import { EntangleSynth } from '../typechain-types/contracts/EntangleSynth';
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleDEXOnDemand } from '../typechain-types/contracts/EntangleDEXOnDemand';
import { ERC20__factory } from "../typechain-types/factories/@openzeppelin/contracts/token/ERC20/ERC20__factory";


const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];
    
describe("BSC Synth Chef", function () {
    let chef: BSCSynthChef;
    let owner: Signer;
    let weth: Contract;
    let wrapper: UniswapWrapper;
    let synthFactory: EntangleSynthFactory;
    let synth: EntangleSynth;
    let chainId: number;
    let DEXonDemand: EntangleDEXOnDemand;
    const PID = 7;
    const WETH_ADDR = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
    const STABLE_ADDR = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d";

    before(async function () {
        owner = (await ethers.getSigners())[0];
        chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;
        console.log(chainId);
        const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        wrapper = await UniswapWrapperFactory.deploy("0x10ED43C718714eb63d5aA57B78B54704E256024E", WETH_ADDR) as UniswapWrapper;
        weth = new ethers.Contract(WETH_ADDR, WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("2")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("BSCSynthChef")) as BSCSynthChef__factory;
        chef = (await ChefFactory.deploy("0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
                "0x10ED43C718714eb63d5aA57B78B54704E256024E",
            wrapper.address,
            STABLE_ADDR,
            ["0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"],
            "1",
            await owner.getAddress())) as BSCSynthChef;
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
        const SynthFactoryFactory = (await ethers.getContractFactory("EntangleSynthFactory")) as EntangleSynthFactory__factory;
        synthFactory = await SynthFactoryFactory.deploy();
        let addr = await synthFactory.previewSynthAddress(chainId, chef.address, PID, STABLE_ADDR);
        await synthFactory.createSynth(chainId, chef.address, PID, STABLE_ADDR);
        synth = EntangleSynth__factory.connect(addr, owner);
        await synthFactory.grantRole(synthFactory.MINT_ROLE(), owner.getAddress());
        await synth.setPrice("1000000000");
        let DEXonDemandFactory = (await ethers.getContractFactory("EntangleDEXOnDemand")) as EntangleDEXOnDemand__factory;
        console.log(chainId, chef.address, PID);
        DEXonDemand = await DEXonDemandFactory.deploy(PID, synthFactory.address, chef.address);
        await DEXonDemand.grantRole(DEXonDemand.ADMIN_ROLE(), owner.getAddress());
        await DEXonDemand.grantRole(DEXonDemand.BUYER(), owner.getAddress());
        await chef.grantRole(chef.ADMIN_ROLE(), DEXonDemand.address);
        await synthFactory.grantRole(synthFactory.MINT_ROLE(), DEXonDemand.address);
    });

    it("Deposit", async function () {
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(PID, weth.address, ethers.utils.parseEther("1.0"), 0);
        expect(await chef.getBalanceOnFarm(PID)).to.be.greaterThan(0);
    });

    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(PID);
        await ethers.provider.send("evm_increaseTime", [3600*24*365]);
        await chef.compound(PID);
        let balanceAfterCompound = await chef.getBalanceOnFarm(PID);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await chef.getBalanceOnFarm(PID);
        await chef.withdraw(PID, STABLE_ADDR, (await chef.getBalanceOnFarm(PID)).div(10), owner.getAddress(), 0);
        let balanceAfterWithdraw = await chef.getBalanceOnFarm(PID);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });

    it("Mint from factory", async function () {
        await synthFactory.mint(chainId, chef.address, PID, "1000000000000000000", owner.getAddress());
        expect(await synth.totalSupply()).to.be.equal("1000000000000000000");
    });

    it("Buy at DEX on Demand", async function () {
        let ERC20Factory = (await ethers.getContractFactory("ERC20")) as ERC20__factory;
        let weth = ERC20Factory.attach(WETH_ADDR);
        await weth.approve(wrapper.address, ethers.constants.MaxUint256);
        await wrapper.convert(WETH_ADDR, STABLE_ADDR, ethers.utils.parseEther("0.05"));
        let stable = ERC20Factory.attach(STABLE_ADDR);
        await stable.approve(DEXonDemand.address, ethers.constants.MaxUint256);
        await DEXonDemand.buy(stable.balanceOf(owner.getAddress()));
    });
});
