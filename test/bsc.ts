import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { ethers } from "hardhat";
import { BSCSynthChef,} from '../typechain-types/contracts/synth-chefs/BSCSynthChef.sol';
import { BSCSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/BSCSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];
    
describe("BSC Synth Chef", function () {
    let chef: BSCSynthChef;
    let owner: Signer;
    let weth: Contract;
    let wrapper: UniswapWrapper;
    before(async function () {
        owner = (await ethers.getSigners())[0];
        const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        wrapper = await UniswapWrapperFactory.deploy("0x10ED43C718714eb63d5aA57B78B54704E256024E") as UniswapWrapper;
        weth = new ethers.Contract("0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("2.0")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("BSCSynthChef")) as BSCSynthChef__factory;
        chef = (await ChefFactory.deploy("0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
                "0x10ED43C718714eb63d5aA57B78B54704E256024E",
            wrapper.address,
            "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
            ["0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"],
            "1",
            await owner.getAddress())) as BSCSynthChef;
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
    });

    it("Deposit", async function () { 
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(7, weth.address, ethers.utils.parseEther("1.0"));
        expect(await chef.getBalanceOnFarm(7)).to.be.greaterThan(0);
    });

    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(7);
        await ethers.provider.send("evm_increaseTime", [3600*24*365]);
        await chef.compound(7);
        let balanceAfterCompound = await chef.getBalanceOnFarm(7);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await chef.getBalanceOnFarm(7);
        await chef.withdraw(7, "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", balanceBeforeWithdraw.div(10), owner.getAddress());
        let balanceAfterWithdraw = await chef.getBalanceOnFarm(7);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});