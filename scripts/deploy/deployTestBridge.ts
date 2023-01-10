import hre from "hardhat";
import { ethers } from "hardhat";
import { EntangleTestBridge__factory } from "../../typechain-types/factories/contracts/bridge/EntangleTestBridge__factory";

import fs from "fs/promises";
import { bridge } from "../../typechain-types/contracts";


export default async function deploy() {
    const owner = (await ethers.getSigners())[0];
    const chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    const BridgeFactory = (await ethers.getContractFactory(
        "EntangleTestBridge"
    )) as EntangleTestBridge__factory;

    let bridge = await BridgeFactory.deploy();
    await bridge.deployed();

    const config = JSON.parse((await fs.readFile("./bridge_config/bridge_config.json")).toString());

    await (await bridge.grantRole(bridge.ADMIN(), config.bridgeKeeperAddress)).wait();

    for (const token in config["tokens"]) {
        let token_conf = config["tokens"][token][(await owner.provider?.getNetwork())!.name];
        let id = token_conf["id"];
        let address = token_conf["address"];
        await (await bridge.addTokenId(id, address)).wait();
    }

    console.log("Bridge address: ", bridge.address);
}