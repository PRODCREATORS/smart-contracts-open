/* TOKENS ETH MAINNET */
export const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
export const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
export const WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
export const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

/* UNISWAP ETH MAINNET */
export const UNSIWAP_ROUTER        = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
export const UniswapPairV2WBTCWETC = "0xBb2b8038a1640196FbE3e38816F3e67Cba72D940";
export const UniswapPairV2WETHUSDT = "0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852";

/* CURVE.FI ETH MAINNET */
export const CRV                                  = "0xD533a949740bb3306d119CC777fa900bA034cd52";
export const BaseRewardPool                       = "0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652";
export const ConverxBooster                       = "0xF403C135812408BFbE8713b5A23a04b3D48AAE31";
export const _3CryptoV2Pool                       = "0xD51a44d3FaE010294C616388b506AcdA1bfAAE46";
export const crv3crypto__gauge                    = "0xDeFd8FdD20e0f34115C7018CCfb655796F6B2168";
export const Curvefi_USD__BTC__ETH                = "0xc4AD29ba4B3c580e6D59105FFf484999997675Ff";
export const Curvefi_USD__BTC__ETH_Convex_Deposit = "0x903C9974aAA431A765e60bC07aF45f0A1B3b61fb";
export const Curvefi_Pool_Math                    = "0x8f68f4810cce3194b6cb6f3d50fa58c2c9bdd1d5";
export const Curvefi_Front_Utils                  = "0x40745803C2faA8E8402E2Ae935933D07cA8f355c";

export const WETH_ABI = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "src", type: "address" },
      { indexed: true, internalType: "address", name: "guy", type: "address" },
      { indexed: false, internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "dst", type: "address" },
      { indexed: false, internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "Deposit",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "src", type: "address" },
      { indexed: true, internalType: "address", name: "dst", type: "address" },
      { indexed: false, internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "src", type: "address" },
      { indexed: false, internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "Withdrawal",
    type: "event",
  },
  { payable: true, stateMutability: "payable", type: "fallback" },
  {
    constant: true,
    inputs: [
      { internalType: "address", name: "", type: "address" },
      { internalType: "address", name: "", type: "address" },
    ],
    name: "allowance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "guy", type: "address" },
      { internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [{ internalType: "address", name: "", type: "address" }],
    name: "balanceOf",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "decimals",
    outputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "deposit",
    outputs: [],
    payable: true,
    stateMutability: "payable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "name",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "symbol",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalSupply",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "dst", type: "address" },
      { internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "transfer",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      { internalType: "address", name: "src", type: "address" },
      { internalType: "address", name: "dst", type: "address" },
      { internalType: "uint256", name: "wad", type: "uint256" },
    ],
    name: "transferFrom",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [{ internalType: "uint256", name: "wad", type: "uint256" }],
    name: "withdraw",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];
