import hre from "hardhat";

import bsc_deploy from "../deploy/deployBSC";
import ftm_deploy from "../deploy/deployFantom";
import avax_deploy from "../deploy/deployAvax";
import eth_deploy from "../deploy/deployETH";
import arb_deploy from "../deploy/deployArbitrum";
import op_deploy from "../deploy/deployOptimism";
import bridge_deploy from "../deploy/deployTestBridge";
import faucet_deploy from "../deploy/deployFaucet";
import mat_deploy from "../deploy/deployPolygon";
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

    switch (net) {
        case "tftm": {
            // const BRIDGE_ADDR = "0xB003e75f7E0B5365e814302192E99b4EE08c0DEd";

            const WETH_ADDR = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
            const STABLE_ADDR = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75";
            const UNISWAP_ROUTER = "0xF491e7B69E4244ad4002BC14e878a34207E38c29";
            const MASTER_CHEF = "0x09855B4ef0b9df961ED097EF50172be3e6F13665";
            const REWARD_TOKEN = "0x5Cc61A78F164885776AA610fb0FE1257df78E59B";

            addresses = await ftm_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                MASTER_CHEF,
                REWARD_TOKEN,
                FAUCET_ADDR
            );
            break;
        }

        case "tavax": {
            // const BRIDGE_ADDR = "0x0EF812f4c68DC84c22A4821EF30ba2ffAB9C2f3A";

            const WETH_ADDR = "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7";
            const STABLE_ADDR = "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E";
            const UNISWAP_ROUTER = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
            const MASTER_CHEF = "0x4483f0b6e2F5486D06958C20f8C39A7aBe87bf8F";
            const REWARD_TOKEN = "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd";

            addresses = await avax_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                MASTER_CHEF,
                REWARD_TOKEN,
                FAUCET_ADDR
            );
            break;
        }

        case "tbsc": {
            // const BRIDGE_ADDR = "0x749F37Df06A99D6A8E065dd065f8cF947ca23697";

            const WETH_ADDR = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
            const STABLE_ADDR = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d";
            const UNISWAP_ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
            const MASTER_CHEF = "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652";
            const REWARD_TOKEN = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
            const PID = 7;

            addresses = await bsc_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                MASTER_CHEF,
                REWARD_TOKEN,
                PID,
                FAUCET_ADDR
            );
            break;
        }
        case "teth": {
            // const BRIDGE_ADDR = "0x2796317b0fF8538F253012862c06787Adfb8cEb6";

            const WETH_ADDR = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
            const STABLE_ADDR = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
            const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
            const MASTER_CHEF = "0xF403C135812408BFbE8713b5A23a04b3D48AAE31";
            const REWARD_TOKEN = ["0xD533a949740bb3306d119CC777fa900bA034cd52"];

            addresses = await eth_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                UNISWAP_ROUTER,
                MASTER_CHEF,
                BRIDGE_ADDR,
                REWARD_TOKEN,
                FAUCET_ADDR
            );
            break;
        }
        case "top": {
            // const BRIDGE_ADDR = "0x470f9522ff620eE45DF86C58E54E6A645fE3b4A7";

            const STABLE_ADDR = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
            const UNISWAP_ROUTER = "0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9";
            const REWARD_TOKEN = ["0x3c8B650257cFb5f272f799F5e2b4e65093a11a05"];

            addresses = await op_deploy(
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                REWARD_TOKEN,
                FAUCET_ADDR
            );
            break;
        }
        case "tarb": {
            // const BRIDGE_ADDR = "0x37f9aE2e0Ea6742b9CAD5AbCfB6bBC3475b3862B";

            const WETH_ADDR = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
            const STABLE_ADDR = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
            const UNISWAP_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
            const REWARD_TOKEN = ["0x6694340fc020c5E6B96567843da2df01b2CE1eb6"];

            addresses = await arb_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                REWARD_TOKEN,
                FAUCET_ADDR
            );
            break;
        }

        case "tmat": {
            // const BRIDGE_ADDR = "0x8F5BBB2BB8c2Ee94639E55d5F41de9b4839C1280"

            const WETH_ADDR =  "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
            const STABLE_ADDR = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
            const UNISWAP_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
            const REWARD_TOKEN = ["0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590"]

            addresses = await mat_deploy(
                WETH_ADDR,
                STABLE_ADDR,
                BRIDGE_ADDR,
                UNISWAP_ROUTER,
                REWARD_TOKEN,
                FAUCET_ADDR
            )
            break;
        }
    }
    fs.writeFileSync(
        path.join(`./scripts/deploy/addresses/${net}_addresses.json`),
        JSON.stringify(addresses, null, 2)
    );
}

scaffold().catch(console.log);
