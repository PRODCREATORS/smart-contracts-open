


import { UniswapWrapper__factory } from './../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { ArbitrumSynthShef, IStargate } from '../typechain-types/contracts/synth-chefs/ArbitrumSynthShef.sol/';
import { ArbitrumSynthShef__factory } from './../typechain-types/factories/contracts/synth-chefs/ArbitrumSynthShef.sol/ArbitrumSynthShef__factory';
import { IStargate__factory } from './../typechain-types/factories/contracts/synth-chefs/ArbitrumSynthShef.sol/IStargate__factory';
import { UniswapWrapper } from './../typechain-types/contracts/dex-wrappers/UniswapWrapper';

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];
describe("Arbitrum Synth Chef", function () {
    let chef: ArbitrumSynthShef;
    let owner: Signer;
    let weth: Contract;
    let lpStaking: IStargate;
    let wrapper: UniswapWrapper;
    before(async function () {
        owner = (await ethers.getSigners())[0];
        console.log(await owner.getBalance());
        const Wrapper = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        wrapper = await Wrapper.deploy("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506") as UniswapWrapper;//SushiSwapRouter
        console.log(wrapper.address);
        lpStaking = IStargate__factory.connect("0xeA8DfEE1898a7e0a59f7527F076106d7e44c2176", owner); //LPStaking.sol
        weth = new ethers.Contract("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", WETH_ABI, owner); //WETH
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("2.0")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("ArbitrumSynthShef")) as ArbitrumSynthShef__factory;
        chef = (await ChefFactory.deploy("0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614",//Router.sol (stargate)
            "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",//WETH
            "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",//USDC
            "1",//fee
            await owner.getAddress(),//treasury
            wrapper.address,//DEXWrapper
            "0x6694340fc020c5E6B96567843da2df01b2CE1eb6")) as ArbitrumSynthShef;//StargateToken.sol 
        console.log(chef.address);
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
        await chef.addPool("0x892785f33CdeE22A30AEF750F285E18c18040c3e", // pool (stargate)
                        "0xeA8DfEE1898a7e0a59f7527F076106d7e44c2176", //LPStaking.sol
                        "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", //USDC
                        0, //poolRouterlID (USDC)
                        1); //poolLpStakingID (USDC)
        console.log(await chef.poolsArray(0)); 
    });

    it("Deposit", async function () { 
        let balance  = await wrapper.previewConvert("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", ethers.utils.parseEther("1.0"));
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(ethers.utils.parseEther("1.0"), weth.address, 0);
        let balancePool = await chef.getAmountsTokensInLP(0);
        console.log("money: " + balancePool);
        let data = await chef.getAmountsTokensInLP(0);
    });
    
    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(0);
        await ethers.provider.send("evm_increaseTime", [3600*24*365]);
        await chef.compound(0);
        let balanceAfterCompound = await chef.getBalanceOnFarm(0);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await (await lpStaking.userInfo("0", chef.address.toString())).amount;
        let amount = balanceBeforeWithdraw.div(10);
        await chef.withdraw(amount, "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", owner.getAddress(), 0);
        let balanceAfterWithdraw = await (await lpStaking.userInfo("0", chef.address.toString())).amount; 
        console.log(balanceBeforeWithdraw + " = " + balanceAfterWithdraw);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});