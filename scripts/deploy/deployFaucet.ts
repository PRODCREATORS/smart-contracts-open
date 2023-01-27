import { ethers } from "hardhat";
import hre from "hardhat";
import { Faucet__factory } from "../../typechain-types/factories/contracts/Faucet__factory";

export default async function deploy() {
    const FaucetFactory = (await ethers.getContractFactory(
        "Faucet"
    )) as Faucet__factory;

    let faucet = await FaucetFactory.deploy()
    await faucet.deployed();

    return faucet.address
}

deploy().catch(console.log);