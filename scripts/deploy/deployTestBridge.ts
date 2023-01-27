import hre from "hardhat";
import { ethers } from "hardhat";
import { EntangleTestBridge__factory } from "../../typechain-types/factories/contracts/bridge/EntangleTestBridge__factory";
import path from "path";
import fs from "fs/promises";


export default async function deploy() {
    const BridgeFactory = (await ethers.getContractFactory(
         "EntangleTestBridge"
    )) as EntangleTestBridge__factory;
    let net = hre.network.name;
    let bridge = await BridgeFactory.deploy();
    await bridge.deployed();

    const config = JSON.parse((await fs.readFile(path.join(__dirname, "bridge_config", "bridge_config.json"))).toString());

    await (await bridge.grantRole(bridge.ADMIN(), config.bridgeKeeperAddress)).wait();

    for (const token in config["tokens"]) {
        let token_conf = config["tokens"][token]["networks"][hre.network.name];
        console.log(token_conf);
        let id = token_conf["id"];
        let address = token_conf["address"];
        await (await bridge.addTokenId(id, address)).wait();
    }

    console.log("Bridge address: ", bridge.address);
    return bridge.address;
}