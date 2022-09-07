import { UniswapWrapper__factory } from './../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { ethers } from "hardhat";
import { FantomSynthChef,} from '../typechain-types/contracts/synth-chefs/FantomSynthChef.sol';
import { FantomSynthChef__factory } from './../typechain-types/factories/contracts/synth-chefs/FantomSynthChef.sol';
import { UniswapWrapper } from './../typechain-types/contracts/dex-wrappers/UniswapWrapper';

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];

describe("Fantom Synth Chef", function () {
    let chef: FantomSynthChef;
    let owner: Signer;
    let weth: Contract;
    let wrapper: UniswapWrapper;
    before(async function () {
        owner = (await ethers.getSigners())[0];
        const UniswapWrapperFactory = await ethers.getContractFactory("UniswapWrapper") as UniswapWrapper__factory; 
        wrapper = await UniswapWrapperFactory.deploy("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83") as UniswapWrapper;
        weth = new ethers.Contract("0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("2.0")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("FantomSynthChef")) as FantomSynthChef__factory;
        chef = (await ChefFactory.deploy("0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614",
            wrapper.address,
            "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
            ["0x5Cc61A78F164885776AA610fb0FE1257df78E59B"],
            "1",
            await owner.getAddress())) as FantomSynthChef;
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
        await chef.addPool("0xAfEcf681a8f3FB8D78581874339Bfca6252d62C4",
            "0x41E57160673a9d1BedfCdE9341B53A61737Cd47E",
            "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
            "0x8c6f28f2f1a3c87f0f938b96d27520d9751ec8d9",
            true);
    });

    it("Deposit", async function () { 
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(ethers.utils.parseEther("1.0"), weth.address, 0);
        expect(await chef.getBalanceOnFarm(0)).to.be.greaterThan(0);
    });
    
    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarm(0);
        await ethers.provider.send("evm_increaseTime", [3600*24*365]);
        await chef.compound(0);
        let balanceAfterCompound = await chef.getBalanceOnFarm(0);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await chef.getBalanceOnFarm(0);
        await chef.withdraw(0, "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", chef.getLPAmountOnFarm(0), owner.getAddress());
        let balanceAfterWithdraw = await chef.getBalanceOnFarm(0);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});