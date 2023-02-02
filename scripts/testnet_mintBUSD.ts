import { BigNumber, Signer } from "ethers";
import { ethers, network } from "hardhat";
const BUSD ='0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';

async function impersonate<T>(addr: string, x:(s: Signer) => Promise<T>): Promise<T> {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [addr],
  });
  const signer = await ethers.getSigner(addr);
  const ret = await x(signer);

  await network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [addr],
  });

  return ret;
}
//const toMint = ethers.BigNumber.from("9244148").mul(BigNumber.from(10).pow());
async function main() {
  const [self] = [{address: '0x69475350714B09b60b2ecc3AA5C407b9D1cAEC86'}]; //await ethers.getSigners();
  console.log(self.address);
  const selfBUSD = await  ethers.getContractAt('BEP20Token', BUSD);
  const bal = await selfBUSD.balanceOf(self.address);
  const toMint = ethers.BigNumber.from('1337').mul(BigNumber.from(10).pow(25)).sub(bal);
  console.log(toMint);
  const owner = await selfBUSD.owner();
  await impersonate(owner, async (signer) => {
    const busd = await ethers.getContractAt('BEP20Token', BUSD, signer);
    const ok = await busd.mint(toMint);
    console.log(await ok.wait());
    await busd.transfer(self.address, toMint);
  });

}

main().then().catch(e=> { console.error(e); process.exit(1)});