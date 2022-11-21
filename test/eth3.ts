import { expect } from "chai";
import { Signer, Contract } from "ethers";
import hre, { ethers } from "hardhat";
import { EthreumSynthChef } from "../typechain-types/contracts/synth-chefs/EthreumSynthChef.sol";
import { EthreumSynthChef__factory } from "../typechain-types/factories/contracts/synth-chefs/EthreumSynthChef.sol";
import { UniswapWrapper } from "../typechain-types/contracts/dex-wrappers/UniswapWrapper";
import { UNSIWAP_ROUTER, WETH, WETH_ABI } from "../constants";

describe("ETH Synth Chef", function () {
  let chef: EthreumSynthChef;
  let owner: Signer;
  let weth: Contract;
  let wrapper: UniswapWrapper;
  before(async function () {
    owner = (await ethers.getSigners())[0];
    console.log(await owner.getChainId());
    const UniswapWrapperFactory = await ethers.getContractFactory(
      "UniswapWrapper"
    );
    wrapper = await UniswapWrapperFactory.deploy(UNSIWAP_ROUTER, WETH);
    weth = new ethers.Contract(WETH, WETH_ABI, owner);

    console.log("Swapping ETH to WETH...");
    await weth.deposit({ value: ethers.utils.parseEther("100.0") });

    console.log("WETH balance:", await weth.balanceOf(owner.getAddress()));
    const ChefFactory = await ethers.getContractFactory("EthreumSynthChef");
    chef = await ChefFactory.deploy(
      "0xF403C135812408BFbE8713b5A23a04b3D48AAE31", //convex
      wrapper.address, //dex interface
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", //stable
      ["0xD533a949740bb3306d119CC777fa900bA034cd52"], //reward
      "1", //fee
      await owner.getAddress()
    ); //fee collector
    await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress());
    await chef.addPool(
      "0xc4AD29ba4B3c580e6D59105FFf484999997675Ff",
      38,
      "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      "0xD51a44d3FaE010294C616388b506AcdA1bfAAE46",
      "0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652"
    );
  });

  it("Deposit", async function () {
    console.log(new Date(), 'start');
    await weth.approve(chef.address, ethers.constants.MaxUint256);
    console.log(new Date(), "APPROVE");
    const tx = await chef.deposit(
      0,
      weth.address,
      ethers.utils.parseEther("1.0"),
      0, { gasLimit: 2500000 } 
    );
    console.log(new Date(), "DEPOSIT");

    expect(await chef.getBalanceOnFarm(0)).to.be.greaterThan(0);
  });

  it("Deposit", async function () {
    console.log(new Date(), 'start');
    const tx = await chef.deposit(
      0,
      weth.address,
      ethers.utils.parseEther("1.0"),
      0, { gasLimit: 2500000 } 
    );
    console.log(new Date(), "DEPOSIT");

    expect(await chef.getBalanceOnFarm(0)).to.be.greaterThan(0);
  });
//  it("Compound", async function () {
//    let balanceBeforeCompound = await chef.getBalanceOnFarm(0);
//    await ethers.provider.send("evm_increaseTime", [3600 * 24 * 365]);
//    await chef.compound(0);
//    let balanceAfterCompound = await chef.getBalanceOnFarm(0);
//    expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
//  });
//
//  it("Withdraw", async function () {
//    let balanceBeforeWithdraw = await chef.getBalanceOnFarm(0);
//    await chef.withdraw(
//      0,
//      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
//      (await chef.getLPAmountOnFarm(0)).div(10),
//      owner.getAddress(),
//      0
//    );
//    let balanceAfterWithdraw = await chef.getBalanceOnFarm(0);
//    expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
//  });
});
