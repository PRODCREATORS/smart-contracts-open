import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { ethers } from "hardhat";
import { AvaxSynthChef,} from '../typechain-types/contracts/synth-chefs/AvaxSynthChef.sol';
import { AvaxSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/AvaxSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];
    
describe("Avax Synth Chef", function () {
    let chef: AvaxSynthChef;
    let owner: Signer;
    let weth: Contract;
    let wrapper: UniswapWrapper;
    before(async function () {
        owner = (await ethers.getSigners())[0];
        const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        wrapper = await UniswapWrapperFactory.deploy("0x60aE616a2155Ee3d9A68541Ba4544862310933d4", "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7") as UniswapWrapper;
        weth = new ethers.Contract("0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7", WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("2.0")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("AvaxSynthChef")) as AvaxSynthChef__factory;
        chef = (await ChefFactory.deploy("0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00", //chef
                "0x60aE616a2155Ee3d9A68541Ba4544862310933d4", //router
            wrapper.address, //dex interface
            "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", //stable
            ["0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd"], //reward
            "1", //fee
            await owner .getAddress())) as AvaxSynthChef; //fee collector
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
    });

    it("Deposit", async function () { 
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(51, weth.address, ethers.utils.parseEther("1.0"));
        expect(await chef.getBalanceOnFarm(51)).to.be.greaterThan(0);
    });

    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(51);
        await ethers.provider.send("evm_increaseTime", [3600*24*365*100]);
        await chef.compound(51);
        let balanceAfterCompound = await chef.getBalanceOnFarm(51);
        expect(balanceAfterCompound).to.be.greaterThanOrEqual(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await chef.getBalanceOnFarm(51);
        await chef.withdraw(51, "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", chef.getLPAmountOnFarm(51), owner.getAddress());
        let balanceAfterWithdraw = await chef.getBalanceOnFarm(51);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});