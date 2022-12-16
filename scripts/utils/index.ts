import { ethers } from "hardhat";
import { EntangleSynth } from "../../typechain-types/contracts/EntangleSynth";
import { BaseSynthChef } from "../../typechain-types/contracts/synth-chefs/BaseSynthChef";
import { EntangleSynthFactory } from "../../typechain-types/contracts/EntangleSynthFactory";
import { IERC20 } from "../../typechain-types/contracts/test/PancakeRouter.sol/IERC20";
import { EntangleDEX } from "../../typechain-types/contracts/EntangleDEX";

export async function transfer(
    _op: string,
    amount: bigint,
    to: string
): Promise<boolean> {
    try {
        const op = (await ethers.getContractAt("IERC20", _op)) as IERC20;
        await op.transfer(to, amount);
        return true;
    } catch (error) {
        console.log(error);
        return false;
    }
}

export async function approve(token: string, address: string) {
        try {
            const _token = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20", token) as IERC20;
            await _token.approve(address, ethers.constants.MaxUint256);
        } catch (error) {
            console.log(error);
        }
}

export async function mint(
    _factory: string,
    chainId: number,
    chef: string,
    pid: number,
    amount: bigint,
    to: string,
    _op: string
) {
    try {
        const factory = await ethers.getContractAt('EntangleSynthFactory', _factory) as EntangleSynthFactory
        let synthAddr = await factory.synths(chainId, chef, pid);
        if (synthAddr == ethers.constants.AddressZero) {
            await (await factory.createSynth(chainId, chef, pid, _op)).wait()
            synthAddr = await factory.synths(chainId, chef, pid);
            const synth = await ethers.getContractAt('EntangleSynth', synthAddr) as EntangleSynth;
            await synth.setPrice("2000000000000000000");
            const idex = await ethers.getContractAt('EntangleDEX', to) as EntangleDEX;
            await idex.add(synth.address);
            console.log(`synth: ${synth.address}`);
        }
        const synth = await ethers.getContractAt('EntangleSynth', synthAddr) as EntangleSynth
        await factory.mint(chainId, chef, pid, amount, to, 0);

        const balance = await synth.balanceOf(to);

        return balance.toBigInt() >= amount ? true : false 
    } catch (error) {
        console.log(error);
        return false;
    }
}

export async function deposit(
    chef: string,
    pid: number,
    tFrom: string,
    amount: bigint
) {
    try {
        const _chef = await ethers.getContractAt('BaseSynthChef', chef) as BaseSynthChef;
        await _chef.deposit(pid, tFrom, amount, 0);
        return true;
    } catch (error) {
        console.log(error);
        return false;
    }
}
