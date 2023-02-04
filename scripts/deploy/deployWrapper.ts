import hre, { ethers } from "hardhat";

import { UniswapWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory";
import { VelodromeWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/VelodromeWrapper.sol";

import { assert } from "console";

import fs from "fs";
import path from "path";

export default async function deployWrapper(): Promise<string> {
    const wrapper_conf = JSON.parse(
        fs.readFileSync(
            path.join(
                __dirname,
                "wrapper_config",
                "wrapper_config.json"
                )).toString());

    let wrapperAddress: string = "";

    switch(hre.network.name) {
        case "tftm":
        case "tavax":
        case "tbsc":
        case "teth":
        case "tarb":
        case "tmat":
            const UniswapWrapperFactory = (await ethers.getContractFactory(
                "UniswapWrapper"
            )) as UniswapWrapper__factory;
            const uniswapWrapper = (await UniswapWrapperFactory.deploy(
                wrapper_conf[hre.network.name].routerAddress,
                wrapper_conf[hre.network.name].wNative
            ));
            await uniswapWrapper.deployed();
            wrapperAddress = uniswapWrapper.address;
            break;
        case "top":
            const VelodromeWrapperFactory = (await ethers.getContractFactory(
                "VelodromeWrapper"
            )) as VelodromeWrapper__factory;
            const velodromWrapper = (await VelodromeWrapperFactory.deploy(
                wrapper_conf[hre.network.name].routerAddress
            ));
            await velodromWrapper.deployed();
            wrapperAddress = velodromWrapper.address;
            break;

        default:
            alert("deployWrapper: unavailable network:" + hre.network.name);
    }

    assert(wrapperAddress !== "", "Wrapper was not deployed");

    return wrapperAddress;
}