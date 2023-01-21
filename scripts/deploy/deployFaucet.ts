import { ethers } from "hardhat";
import hre from "hardhat";
import { Faucet__factory } from "../../typechain-types/factories/contracts/Faucet__factory";
import fs from "fs/promises";
import path from "path";

export default async function deploy() {
    const FaucetFactory = (await ethers.getContractFactory(
        "Faucet"
    )) as Faucet__factory;
    
    let faucet = await FaucetFactory.deploy()
    await faucet.deployed();
    await fs.writeFile(
        path.join(__dirname, "addresses", `${hre.network.name}_addressesFaucet.json`),
        JSON.stringify({
            faucet: faucet.address
        })
    );

    return faucet.address
}

deploy().catch(console.log);