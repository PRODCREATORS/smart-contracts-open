import hre, { ethers } from "hardhat";

import { BSCSynthChef,} from '../typechain-types/contracts/synth-chefs/BSCSynthChef.sol';
import { BSCSynthChef__factory } from '../typechain-types/factories/contracts/synth-chefs/BSCSynthChef.sol';
import { UniswapWrapper } from '../typechain-types/contracts/dex-wrappers/UniswapWrapper';
import { EntangleSynthFactory__factory } from "../typechain-types/factories/contracts/EntangleSynthFactory__factory";
import { EntangleSynth__factory } from "../typechain-types/factories/contracts/EntangleSynth__factory";
import { EntangleSynthFactory } from '../typechain-types/contracts/EntangleSynthFactory';
import { EntangleSynth } from '../typechain-types/contracts/EntangleSynth';
import { EntangleDEXOnDemand__factory } from "../typechain-types/factories/contracts/EntangleDEXOnDemand__factory";
import { EntangleDEXOnDemand } from '../typechain-types/contracts/EntangleDEXOnDemand';
import { ERC20__factory } from "../typechain-types/factories/@openzeppelin/contracts/token/ERC20/ERC20__factory";
import { UniswapWrapper__factory } from '../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory'

async function main() {
  let owner = (await ethers.getSigners())[0];
  const WETH_ADDR = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
  
  let wrapper = "0xe8D77c300D86Ada2E55e8af89e2dA2B7F5C32ab5";
  const ChefFactory = (await ethers.getContractFactory("BSCSynthChef")) as BSCSynthChef__factory;
  await ChefFactory.deploy("0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
          "0x10ED43C718714eb63d5aA57B78B54704E256024E",
      wrapper.address
      STABLE_ADDR
      ["0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"],
      "1",
      await owner.getAddress())) as BSCSynthChef;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});