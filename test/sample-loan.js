const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers");

let SynthLpContract;
let EnUSDContract;
let loanContract;

describe("Loan Test", function () {
    let SynthLpContract;
    let EnUSDContract;
    let LoanContract;
    let owner;
    before(async function () {
        const SynthLpFactory = await ethers.getContractFactory("SynthLp");
        const EnUSDFactory = await ethers.getContractFactory("EnUSD");
        const LoanFactory = await ethers.getContractFactory("SilentLoan");

        SynthLpContract = await SynthLpFactory.deploy();
        await SynthLpContract.deployed();

        EnUSDContract = await EnUSDFactory.deploy();
        await EnUSDContract.deployed();

        LoanContract = await LoanFactory.deploy(SynthLpContract.address, EnUSDContract.address, 90);
        await LoanContract.deployed();

        [owner, addr1, addr2] = await ethers.getSigners();
    });

    it("Should return SynthLp balance of owner", async function () {
        expect(await SynthLpContract.balanceOf(owner.address)).to.equal("200000000000000000000000");
    });

    it("Should return EnUSD balance of owner", async function () {
        expect(await EnUSDContract.balanceOf(owner.address)).to.equal("200000000000000000000000");
    });

    it("Should return synthlp address stores in loan contract", async function () {
        expect(await LoanContract.SynthLp).to.equal(SynthLpContract.address);
    });

    it("Should return enusd address stores in loan contract", async function () {
        expect(await LoanContract.EnUSD).to.equal(EnUSDContract.address);
    });

    it("Should return collateral value", async function () {
        expect(await LoanContract.c_r).to.equal("90");
    });

    it("Deposit should work correctly", async function () {
        await LoanContract.deposit("5000");
        expect(await LoanContract.getAccountToDepositAmount(owner)).to.equal("5000");
    });

    it("Borrow should work correctly", async function () {
        await LoanContract.borrow("3000");
        expect(await LoanContract.getAccountToBorrowAmount(owner)).to.equal("2700");
    });
});
