import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { ethers } from "hardhat";
import { AvaxSynthChef,} from '../typechain-types/contracts/synth-chefs/AvaxSynthChef.sol';
import { AvaxSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/AvaxSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleSynthFactory } from '../typechain-types/contracts/EntangleSynthFactory';
import { EntangleSynth } from '../typechain-types/contracts/EntangleSynth';
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleDEXOnDemand } from '../typechain-types/contracts/EntangleDEXOnDemand';
import { ERC20__factory } from "../typechain-types/factories/@openzeppelin/contracts/token/ERC20/ERC20__factory";

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];

describe("Avax Synth Chef", function () {
    let chef: AvaxSynthChef;
    let owner: Signer;
    let weth: Contract;
    let wrapper: UniswapWrapper;
    let synthFactory: EntangleSynthFactory;
    let synth: EntangleSynth;
    let chainId: number;
    let DEXonDemand: EntangleDEXOnDemand;
    const PID = 51;
    const WETH_ADDR = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    const STABLE_ADDR = "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E";

    before(async function () {
        owner = (await ethers.getSigners())[0];
        const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;
        wrapper = await UniswapWrapperFactory.deploy("0x60aE616a2155Ee3d9A68541Ba4544862310933d4", WETH_ADDR) as UniswapWrapper;
        weth = new ethers.Contract(WETH_ADDR, WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("0.05")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("AvaxSynthChef")) as AvaxSynthChef__factory;
        chef = (await ChefFactory.deploy("0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00", //chef
                "0x60aE616a2155Ee3d9A68541Ba4544862310933d4", //router
            wrapper.address, //dex interface
            STABLE_ADDR, //stable
            ["0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd"], //reward
            "1", //fee
            await owner .getAddress())) as AvaxSynthChef; //fee collector
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
        await chef.deposit(PID, weth.address, ethers.utils.parseEther("1.0"));
        expect(await chef.getBalanceOnFarm(PID)).to.be.greaterThan(0);
    });

    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(PID);
        await ethers.provider.send("evm_increaseTime", [3600*24*365*100]);
        await chef.compound(PID);
        let balanceAfterCompound = await chef.getBalanceOnFarm(PID);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await chef.getBalanceOnFarm(PID);
        await chef.withdraw(PID, "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", chef.getLPAmountOnFarm(PID), owner.getAddress());
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