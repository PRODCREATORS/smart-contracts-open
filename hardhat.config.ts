import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ganache";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-tracer";
import "@nomiclabs/hardhat-vyper";
import { nameTags } from "./nameTags";
import "./scripts/fillCStpl";

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          viaIR: true,
        },
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.6.12",
      },
      { version: "0.5.16" },
    ],
  },
  networks: {
    hardhat: {
      // mining: {
      //   auto: false,
      //   interval: [5000, 5000],
      // },
      chainId: Number(process.env.CHAIN_ID || 1337),
      forking: {
        url: "https://rpc.ankr.com/eth",
        // blockNumber: Number(process.env.FROM_BLOCK) || 228,
      },
      // accounts: [
      //   {
      //     balance: "100000000000000000000000000000",
      //     privateKey: process.env.PRIVATE_KEY as string,
      //   },
      // ],
    },

    teth: {
      url: "https://nodes.test.entangle.fi/rpc/eth",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    tbsc: {
      url: "https://nodes.test.entangle.fi/rpc/bsc",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    tavax: {
      url: "https://nodes.test.entangle.fi/rpc/avalanche",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    tftm: {
      url: "https://nodes.test.entangle.fi/rpc/fantom",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    top: {
      url: "https://nodes.test.entangle.fi/rpc/optimism",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    tarb: {
      url: "https://nodes.test.entangle.fi/rpc/arbitrum",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    tmat: {
      url: "https://nodes.test.entangle.fi/rpc/polygon",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    ftm: {
      url: "https://rpc.ftm.tools",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    avax: {
      url: "https://avalanche-evm.publicnode.com",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    bsc: {
      url: "https://bsc-mainnet.public.blastapi.io",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    eth: {
      url: "https://eth-rpc.gateway.pokt.network",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    op: {
      url: "https://1rpc.io/op",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
    arb: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
  },
  vyper: {
    version: "0.2.12",
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_KEY,
  },
  mocha: {
    timeout: 100000000,
  },
  tracer: {
    nameTags,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
};

export default config;
