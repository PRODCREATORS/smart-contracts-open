import hre from "hardhat";

/*
import bsc_deploy from "../deploy/deployBSC";
import ftm_deploy from "../deploy/deployFantom";
import avax_deploy from "../deploy/deployAvax";
import eth_deploy from "../deploy/deployETH";
import arb_deploy from "../deploy/deployArbitrum";
import op_deploy from "../deploy/deployOptimism";
import mat_deploy from "../deploy/deployPolygon";
*/
import deployContracts from "../deploy/deployContracts";
import bridge_deploy from "../deploy/deployTestBridge";
import faucet_deploy from "../deploy/deployFaucet";

import fs from "fs";
import path from "path";

export async function scaffold(net: string = hre.network.name) {

    let addresses;
    if (fs.existsSync(`./scripts/deploy/addresses/${net}_addresses.json`)) {
        addresses = JSON.parse(fs.readFileSync(`./scripts/deploy/addresses/${net}_addresses.json`).toString());
    }
    else {
        addresses = {};
    }
    let BRIDGE_ADDR;
    if (addresses.bridge === "" || addresses.bridge === undefined) {
        BRIDGE_ADDR = await bridge_deploy();
    }
    else {
        BRIDGE_ADDR = addresses.bridge;
    }
    let FAUCET_ADDR;
    if (addresses.faucet === "" || addresses.faucet === undefined) {
        FAUCET_ADDR = await faucet_deploy();
    }
    else {
        FAUCET_ADDR = addresses.faucet;
    }

    addresses = await deployContracts(BRIDGE_ADDR);
    addresses = {...addresses, faucet: FAUCET_ADDR}
    fs.writeFileSync(
        path.join(`./scripts/deploy/addresses/${net}_addresses.json`),
        JSON.stringify(addresses, null, 2)
    );
}

scaffold().catch(console.log);
