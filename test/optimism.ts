import { expect } from "chai";
import { Signer, BigNumber, Contract } from "ethers";
import { ethers } from "hardhat"
import { ETHSynthChefV1 } from "../typechain-types/contracts/idex/ethSynth/ETHSynthChefV1.sol";
import { OptimismSynthChefV1, IGauge } from "../typechain-types/contracts/idex/optimismSynth/OptimismSynthChefV1.sol/";
import { OptimismSynthChefV1__factory } from "../typechain-types/factories/contracts/idex/optimismSynth/OptimismSynthChefV1.sol/OptimismSynthChefV1__factory";
import { IGauge__factory } from "../typechain-types/factories/contracts/idex/optimismSynth/OptimismSynthChefV1.sol/IGauge__factory";
import { IVelodromeRouter, RouteStruct } from "../typechain-types/contracts/idex/optimismSynth/OptimismSynthChefV1.sol/IVelodromeRouter";
import { IVelodromeRouter__factory } from "../typechain-types/factories/contracts/idex/optimismSynth/OptimismSynthChefV1.sol/IVelodromeRouter__factory";
import { IERC20 } from "../typechain-types/@openzeppelin/contracts/token/ERC20/IERC20";
import { IERC20__factory } from "../typechain-types/factories/@openzeppelin/contracts/token/ERC20/IERC20__factory";

const WETH_ABI = [{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"guy","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Deposit","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":true,"internalType":"address","name":"dst","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"src","type":"address"},{"indexed":false,"internalType":"uint256","name":"wad","type":"uint256"}],"name":"Withdrawal","type":"event"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"guy","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"deposit","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"src","type":"address"},{"internalType":"address","name":"dst","type":"address"},{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"uint256","name":"wad","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];
describe("Optimism Synth Chef", function () {
    let chef: OptimismSynthChefV1;
    let owner: Signer;
    let velodrome: IVelodromeRouter;
    let weth: Contract;
    let gauge: IGauge;

    before(async function () {
        owner = (await ethers.getSigners())[0];
        console.log(await owner.getBalance());
        gauge = IGauge__factory.connect("0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80", owner);
        weth = new ethers.Contract("0x4200000000000000000000000000000000000006", WETH_ABI, owner);
        console.log("Swapping ETH to WETH...");
        await weth.deposit({ value: ethers.utils.parseEther("1.0")});
        console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
        const ChefFactory = (await ethers.getContractFactory("OptimismSynthChefV1")) as OptimismSynthChefV1__factory;
        chef = (await ChefFactory.deploy("0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9",
            "0x4200000000000000000000000000000000000006",
            "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
            "0x25CbdDb98b35ab1FF77413456B31EC81A6B6B746",
            "1",
            await owner.getAddress(),
            "0x3c8B650257cFb5f272f799F5e2b4e65093a11a05")) as OptimismSynthChefV1;
        await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
        await chef.addPool("0xd16232ad60188b68076a235c65d692090caba155",
                        gauge.address,
                        "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
                        "0x8c6f28f2f1a3c87f0f938b96d27520d9751ec8d9",
                        true);
    });

    it("Deposit", async function () {
        await weth.approve(chef.address, ethers.constants.MaxUint256);
        await chef["deposit(uint256,address,uint256)"](ethers.utils.parseEther("1.0"), weth.address, 0);
        let data = await chef.getAmountsTokensInLP(0);
    });

    it("Compound", async function () {
        let balanceBeforeCompound = await chef.getBalanceOnFarms(0);
        await ethers.provider.send("evm_increaseTime", [3600*24*365]);
        await chef.compound(0);
        let balanceAfterCompound = await chef.getBalanceOnFarms(0);
        expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    });

    it("Withdraw", async function () {
        let balanceBeforeWithdraw = await gauge.balanceOf(chef.address);
        let amount = balanceBeforeWithdraw.div(10);
        await chef.withdraw(amount, "0x3c8B650257cFb5f272f799F5e2b4e65093a11a05", owner.getAddress(), 0);
        let balanceAfterWithdraw = await gauge.balanceOf(chef.address);
        expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
});