import { UniswapWrapper__factory } from "../../typechain-types/factories/contracts/dex-wrappers/UniswapWrapper__factory";
import { ethers } from "hardhat";
import { UniswapWrapper } from "../../typechain-types/contracts/dex-wrappers/UniswapWrapper";
import { EntangleRouter__factory } from "../../typechain-types/factories/contracts/EntangleRouter.sol/EntangleRouter__factory";
import { EntanglePool__factory } from "../../typechain-types/factories/contracts/EntanglePool__factory";
import hre from "hardhat";
import fs from "fs/promises";
import path from "path";
import { ETHSynthChef__factory } from "../../typechain-types/factories/contracts/synth-chefs/ETHSynthChef.sol";

export default async function deploy(
    WETH_ADDR: string,
    STABLE_ADDR: string,
    UNISWAP_ROUTER: string,
    MASTER_CHEF: string,
    REWARD_TOKEN: string[]
) {
    const PID = 26;

    let owner = (await ethers.getSigners())[0];

    const PoolFactory = (await ethers.getContractFactory(
        "EntanglePool"
    )) as EntanglePool__factory;
    const RouterFactory = (await ethers.getContractFactory(
        "EntangleRouter"
    )) as EntangleRouter__factory;
    const UniswapWrapperFactory = (await ethers.getContractFactory(
        "UniswapWrapper"
    )) as UniswapWrapper__factory;
    const ChefFactory = (await ethers.getContractFactory(
        "ETHSynthChef"
    )) as ETHSynthChef__factory;

    let wrapper = (await UniswapWrapperFactory.deploy(
        UNISWAP_ROUTER,
        WETH_ADDR
    )) as UniswapWrapper;
    await wrapper.deployed();
    let chef = await ChefFactory.deploy(
        MASTER_CHEF, //chef
        wrapper.address, //dex interface
        STABLE_ADDR, //stable
        REWARD_TOKEN, //reward
        "1", //fee
        await owner.getAddress()
    ); //fee collector
    await chef.deployed();

    let pool = await PoolFactory.deploy();
    await pool.deployed();

    let router = await RouterFactory.deploy(
        pool.address,
        '0x0000000000000000000000000000000000000000',
        chef.address,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        2500,
        4,
        2
    );
    await router.deployed();

    await (await chef.grantRole(chef.ADMIN_ROLE(), owner.getAddress())).wait();
    await (await router.grantRole(router.ADMIN(), owner.getAddress())).wait();
    await (await pool.grantRole(pool.DEPOSITER_ROLE(), router.address)).wait();
    await (
        await pool.grantRole(pool.DEPOSITER_ROLE(), owner.getAddress())
    ).wait();
    await (await chef.grantRole(chef.ADMIN_ROLE(), router.address)).wait();

    await chef.addPool(
        "0x02d341CcB60fAaf662bC0554d13778015d1b285C",
        PID,
        "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "0x57Ab1ec28D129707052df4dF418D58a2D46d5f51",
        "0xEB16Ae0052ed37f479f7fe63849198Df1765a733",
        "0xF86AE6790654b70727dbE58BF1a863B270317fD0"
    );

    console.log("Wrapper:", wrapper.address);
    console.log("Synth chef:", chef.address);
    console.log("Router:", router.address);
    console.log("Pool:", pool.address);

    await fs.writeFile(
        path.join(__dirname, "addresses", `${hre.network.name}_addresses.json`),
        JSON.stringify({
            wrapper: wrapper.address,
            chef: chef.address,
            router: router.address,
            pool: pool.address,
            opToken: STABLE_ADDR,
        })
    );

    return {
        wrapper: wrapper.address,
        chef: chef.address,
        router: router.address,
        pool: pool.address,
    };
}
