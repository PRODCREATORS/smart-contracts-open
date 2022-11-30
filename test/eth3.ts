import { assert, expect } from "chai";
import { BigNumber } from "ethers";
import hre, { ethers } from "hardhat";
import * as mainnet from "../constants";

async function trace<T>(fn: () => Promise<T>): Promise<T> {
  hre.tracer.enabled = !!process.env.TRACE;
  const out = await fn();
  hre.tracer.enabled = false;
  return out;
}

async function verifyForkChainId() {
  const fork = new ethers.providers.JsonRpcProvider(process.env.FORK_URL);
  const network = await fork.getNetwork();
  if(network.chainId !== 1) {
    console.error('This test is designed for ETH Mainnet, check your FORK_URL environment variable');
    process.exit(1);
  }
}

describe("ETH Synth Chef", async function () {
  it("Using correct chain for the fork",async () => { await verifyForkChainId() })
  async function chefFixture() {
    const [owner] = await ethers.getSigners();

    const UniswapWrapperFactory = await ethers.getContractFactory(
      "UniswapWrapper"
    );
    const ChefFactory = await ethers.getContractFactory("TricryptoSynthChef");

    const wETH = await ethers.getContractAt("WETH", mainnet.WETH);
    wETH.deposit({ value: ethers.utils.parseEther("1") });

    const UniswapWrapper = await UniswapWrapperFactory.deploy(
      mainnet.UNSIWAP_ROUTER,
      mainnet.WETH
    );
    await UniswapWrapper.deployed();

    const chef = await ChefFactory.deploy(
      mainnet._3CryptoV2Pool,
      mainnet.crv3crypto__gauge,
      UniswapWrapper.address,
      mainnet.USDC,
      [mainnet.CRV],
      "1",
      owner.address
    );
    await chef.deployed();

    await chef.grantRole(chef.ADMIN_ROLE(), owner.address);

    return { wETH, chef, owner };
  }

  describe("Basic functions", async () => {
    let { chef, wETH, owner } = {} as Awaited<ReturnType<typeof chefFixture>>;

    it("Deploys", async () => {
      const fixture = await chefFixture();
      chef = fixture.chef;
      wETH = fixture.wETH;
      owner = fixture.owner;
    });

    it("Deposit", async function () {
      const lpAddr = await chef.lpToken();
      const LP = await ethers.getContractAt("ERC20", lpAddr);

      let balance = await LP.balanceOf(chef.address);
      expect(balance.eq(0)).to.be.true;

      await wETH.approve(chef.address, ethers.constants.MaxUint256);

      const tx = await trace(() =>
        chef.deposit(0, wETH.address, ethers.utils.parseEther("1.0"), 0, {
          gasLimit: 2500000,
        })
      );

      const receipt = await tx.wait(1);
      const event = receipt.events?.find(e => e.event === 'ExpectLPs');
      assert(event && event.args);
      
      const expectedAmount = event.args[0] as BigNumber;

      balance = await LP.balanceOf(chef.address);
      console.log(expectedAmount, balance);
      expect(balance.eq(expectedAmount));
    });

    it("getBalanceOnFarm", async function () {
      const bal = await trace(() => chef.getBalanceOnFarm(0));
      console.log(bal);
    });

    // it("Compound", async function () {
    //   let balanceBeforeCompound = await chef.getBalanceOnFarm(0);
    //   await ethers.provider.send("evm_increaseTime", [3600 * 24 * 365]);
    //   const tx = await chef.compound(0, { gasLimit: 2500000 });
    //   await tx.wait(1);
    //   let balanceAfterCompound = await chef.getBalanceOnFarm(0);
    //   console.log({ balanceBeforeCompound, balanceAfterCompound })
    //   //expect(balanceAfterCompound).to.be.greaterThan(balanceBeforeCompound);
    // });
    it("User checkpoint", async function () {
     const gague = await chef.getGauge();
     const g = await ethers.getContractAt('ILiquidityGaugeV3', gague);

     await trace(() => g.user_checkpoint(owner.address));

    })
    it("Withdraw", async function () {
      let balanceBeforeWithdraw = await chef.getBalanceOnFarm(0);
      //await ethers.provider.send("evm_increaseTime", [3600 * 24 * 365]);
      let amount = await chef.getLPAmountOnFarm(0);
          amount = amount.div(10);

      
      console.log("Amount to withdraw",  amount.lt("25613014622422005801572"));
      hre.tracer.enabled = true;
      const tx = await chef.withdraw(
        0,
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        amount,
        owner.getAddress(),
        0,
      ); // TODO: FAILS AT get_relative_weight <---- WRONG!
      // We are just withdrawing more than we have
      console.log(tx.hash)
      await tx.wait(1)
      console.log(tx.hash);
      let balanceAfterWithdraw = await chef.getBalanceOnFarm(0);
      console.log({ balanceBeforeWithdraw, balanceAfterWithdraw})
      //expect(balanceAfterWithdraw).to.be.lessThan(balanceBeforeWithdraw);
    });
  });
});
