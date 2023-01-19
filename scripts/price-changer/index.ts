import { ethers } from 'hardhat';
import Config from '../../hardhat.config';
import { synthInfo } from '../synth';

type SynthInfoKeys = keyof typeof synthInfo;
type TestnetConfigT = Record<string, { url: string, accounts: { mnemonic: string }}>;

async function main() {
  const networks = Config.networks!;
  // Assume all test nets prefixed with the `t`
  const testnets = Object.fromEntries(Object.entries(networks).filter(([k,v]) => k.startsWith('t') && k !== 'teth')) as TestnetConfigT

  console.log(testnets);

  for(const [k,v] of Object.entries(testnets)) {
    const config = synthInfo[(k as SynthInfoKeys)];

    const provider = new ethers.providers.JsonRpcProvider(v.url);
    const mnemo = ethers.Wallet.fromMnemonic(v.accounts.mnemonic);
    const wallet = new ethers.Wallet(mnemo.privateKey, provider);

    const factory = await ethers.getContractAt('EntangleSynthFactory', config.factory, wallet);
    const synthAddress = await factory.synths(config.chainId, config.chef, config.pid);
    const synth = await ethers.getContractAt('EntangleSynth', synthAddress, wallet);
    const totalSupply = await synth.totalSupply();

    const chef = await ethers.getContractAt('BaseSynthChef', config.chef, wallet);
    const lpAmount = chef.getLPAmountOnFarm(config.pid);
    
  }
}

main().then().catch((e) => {
  console.error(e);
  process.exit(1);
})