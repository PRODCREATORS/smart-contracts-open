import { expect } from "chai";
import { VelodromeWrapper__factory } from "./../typechain-types/factories/contracts/dex-wrappers/VelodromeWrapper.sol/";
import { Signer, BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { OptimismSynthChef, IGauge } from "../typechain-types/contracts/synth-chefs/OptimismSynthChef.sol/";
import { OptimismSynthChef__factory } from "../typechain-types/factories/contracts/synth-chefs/OptimismSynthChef.sol/OptimismSynthChef__factory";
import { IGauge__factory } from "../typechain-types/factories/contracts/synth-chefs/OptimismSynthChef.sol/IGauge__factory";
import { IVelodromeRouter } from "../typechain-types/contracts/synth-chefs/OptimismSynthChef.sol/IVelodromeRouter";

const WETH_ABI = [{ "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "src", "type": "address" }, { "indexed": true, "internalType": "address", "name": "guy", "type": "address" }, { "indexed": false, "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "Approval", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "dst", "type": "address" }, { "indexed": false, "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "Deposit", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "src", "type": "address" }, { "indexed": true, "internalType": "address", "name": "dst", "type": "address" }, { "indexed": false, "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "Transfer", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "src", "type": "address" }, { "indexed": false, "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "Withdrawal", "type": "event" }, { "payable": true, "stateMutability": "payable", "type": "fallback" }, { "constant": true, "inputs": [{ "internalType": "address", "name": "", "type": "address" }, { "internalType": "address", "name": "", "type": "address" }], "name": "allowance", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [{ "internalType": "address", "name": "guy", "type": "address" }, { "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "approve", "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": true, "inputs": [{ "internalType": "address", "name": "", "type": "address" }], "name": "balanceOf", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": true, "inputs": [], "name": "decimals", "outputs": [{ "internalType": "uint8", "name": "", "type": "uint8" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [], "name": "deposit", "outputs": [], "payable": true, "stateMutability": "payable", "type": "function" }, { "constant": true, "inputs": [], "name": "name", "outputs": [{ "internalType": "string", "name": "", "type": "string" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": true, "inputs": [], "name": "symbol", "outputs": [{ "internalType": "string", "name": "", "type": "string" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": true, "inputs": [], "name": "totalSupply", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [{ "internalType": "address", "name": "dst", "type": "address" }, { "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "transfer", "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": false, "inputs": [{ "internalType": "address", "name": "src", "type": "address" }, { "internalType": "address", "name": "dst", "type": "address" }, { "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "transferFrom", "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": false, "inputs": [{ "internalType": "uint256", "name": "wad", "type": "uint256" }], "name": "withdraw", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }];
describe("Optimism Synth Chef", function () {
    let chef: OptimismSynthChef;
    let owner: Signer;
    let weth: Contract;

    before(async function () {
        owner = (await ethers.getSigners())[0];
        console.log(await owner.getBalance());
        let velodromeWrapperFactory = (await ethers.getContractFactory("VelodromeWrapper")) as VelodromeWrapper__factory;
        let velodromeWrapper = await velodromeWrapperFactory.deploy("0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9");
        weth = new ethers.Contract("0x4200000000000000000000000000000000000006", WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("1.0") });
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("OptimismSynthChef")) as OptimismSynthChef__factory;
        chef = (await ChefFactory.deploy("0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9",
                velodromeWrapper.address, "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", ["0x3c8B650257cFb5f272f799F5e2b4e65093a11a05"])) as OptimismSynthChef;
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
        await chef.addPool("0xd16232ad60188b68076a235c65d692090caba155",
            "0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80",
            "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
            "0x8c6f28f2f1a3c87f0f938b96d27520d9751ec8d9",
            true);
    });

    it("Deposit", async function () {
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef.deposit(0, weth.address, ethers.utils.parseEther("1.0"));
        let data = await chef.getBalanceOnFarm(0);
        console.log(data);
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
        let amount = balanceBeforeWithdraw.div(10);
        await chef.withdraw(0, chef.stablecoin(), amount, owner.getAddress());
        let balanceAfterWithdraw = await chef.getBalanceOnFarm(0);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});