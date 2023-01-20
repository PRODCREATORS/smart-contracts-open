import { BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import Config from '../../hardhat.config';
import { EntangleSynth } from '../../typechain-types';
import { synthInfo } from '../synth';

type SynthInfoKeys = keyof typeof synthInfo;
type TestnetConfigT = Record<string, { url: string, accounts: { mnemonic: string }}>;

class DefaultDict {
  constructor(defaultInit: any) {
    return new Proxy({}, {
      get: (target: any, name) => name in target ?
        target[name] :
        (target[name] = typeof defaultInit === 'function' ?
          new defaultInit().valueOf() :
          defaultInit)
    })
  }
}

const DECIMALS = 18;

function price(tlv: BigNumberish, opTokenDecimals: number, synthAmt: BigNumberish) {
  const decimal = (x: BigNumberish) => BigNumber.from(10).pow(x);

  //  tlvDecimalAdjusted = tlvInOpTokenWEI * (10 ** DECIMALS)
  let tlvDecimalAdjusted = BigNumber.from(tlv).mul(decimal(DECIMALS));

  //  price = tlvDecimalAdjusted / synthAmt
  let price = tlvDecimalAdjusted.div(synthAmt);
  
  //  price = price * (10 ** (DECIMALS - opTokenDecimals))
      price = price.mul(decimal(DECIMALS - opTokenDecimals));
    
  return price;
}
class SynthMeta {
  constructor(
    public tlv = BigNumber.from(0),
    public circulation = BigNumber.from(0),
    public opTokenDecimals = 18,
    public synths: EntangleSynth[] = [],
  ) {}

  public setTlv(bn: BigNumber) {
    this.tlv = bn;
  }

  public addSupply(bn: BigNumber) {
    this.circulation.add(bn);
  }
  public setDecimals(x: number) {
    this.opTokenDecimals = x;
  }

  public getPrice() {
    // Set price to uint256 max so synth would be practically unobtainable
    // if we are short on circulation or backing asset
    if (this.circulation.eq(0) || this.tlv.eq(0)) {
      return ethers.constants.MaxUint256; 
    }
    return price(this.tlv, this.opTokenDecimals, this.circulation);
  }
  public pushSynth(s: EntangleSynth) {
    this.synths.push(s);
  }
}

async function main() {
  const networks = Config.networks!;
  // Assume all test nets prefixed with the `t`
  const testnets = Object.fromEntries(Object.entries(networks).filter(([k,v]) => k.startsWith('t') && k !== 'teth')) as TestnetConfigT

  console.log(testnets);
  const synthMeta = new DefaultDict(SynthMeta) as Record<string, SynthMeta>;
  // Iterate over all networks 
  for(const [k,v] of Object.entries(testnets)) {
    const config = synthInfo[(k as SynthInfoKeys)];
    // Setup rpcs and wallets from mnemonics
    const provider = new ethers.providers.JsonRpcProvider(v.url);
    const mnemo = ethers.Wallet.fromMnemonic(v.accounts.mnemonic);
    const wallet = new ethers.Wallet(mnemo.privateKey, provider);

    const factory = await ethers.getContractAt('EntangleSynthFactory', config.factory, wallet); 
    console.log('---- ', config.chainId, factory.address);
    // Iterate over all onchain synths
    for (const [network, info] of Object.entries(synthInfo)) {
      const synthId = `${info.chainId}_${info.chef}_${info.pid}`;
      console.log(synthId);
      // If we hit the network of origin (where SynthChef is deployed) 
      // just collect the tlv and some info about opToken
      if (k === network) {
        const chef = await ethers.getContractAt('BaseSynthChef', config.chef, wallet);
        const tlv = await chef.getBalanceOnFarm(config.pid);
        synthMeta[synthId].setTlv(tlv);

        const opToken = await ethers.getContractAt('ERC20', config.stable, wallet);
        const decimals = await opToken.decimals(); 
        synthMeta[synthId].setDecimals(decimals);

        continue;
      }
      // Get the amount of synth minted on this chain 
      // and accumulate it to get the total circulation 
      // of this synth across all chains.
      // Also save the synth itself for future reference
      const synthAddress = await factory.synths(info.chainId, info.chef, info.pid);
      const synth = await ethers.getContractAt('EntangleSynth', synthAddress, wallet);
      const totalSupply = await synth.totalSupply();

      synthMeta[synthId].addSupply(totalSupply);
      synthMeta[synthId].pushSynth(synth);
    }
  }

  console.log(synthMeta);
  // Update the prices after we collected all the info from all chains
  for(const [k,v] of Object.entries(synthMeta)) {
    for(const synth of v.synths) {
      const newPrice = v.getPrice();
      console.log(k, '|', synth.address, '->', newPrice);
      await synth.setPrice(newPrice);
    }
  }
}

main().then().catch((e) => {
  console.error(e);
  process.exit(1);
})