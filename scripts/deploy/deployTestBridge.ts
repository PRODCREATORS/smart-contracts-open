import hre from "hardhat";
import { ethers } from "hardhat";
import { EntangleTestBridge__factory } from "../../typechain-types/factories/contracts/bridge/EntangleTestBridge__factory";
import path from "path";
import fs from "fs/promises";


export default async function deploy() {
    // const owner = (await ethers.getSigners())[0];
    // const chainId = (await owner.provider?.getNetwork())?.chainId ?? 0;

    // const BridgeFactory = (await ethers.getContractFactory(
    //     "EntangleTestBridge"
    // )) as EntangleTestBridge__factory;
    let net = hre.network.name;
    // let bridge = await BridgeFactory.deploy();
    // await bridge.deployed();
    // console.log(__dirname);
    const config = JSON.parse((await fs.readFile(path.join(__dirname, "bridge_config", "bridge_config.json"))).toString());
    const configBridge = JSON.parse((await fs.readFile(path.join(__dirname, "addresses", `${net}_addresses.json`))).toString());
    console.log(config);
    // await (await bridge.grantRole(bridge.ADMIN(), config.bridgeKeeperAddress)).wait();

    // for (const token in config["tokens"]) {
    //     let token_conf = config["tokens"][token]["networks"][hre.network.name];
    //     console.log(token_conf);
    //     let id = token_conf["id"];
    //     let address = token_conf["address"];
    //     await (await bridge.addTokenId(id, address)).wait();
    // }

    console.log("Bridge address: ", configBridge.bridge);
    return configBridge.bridge;
}