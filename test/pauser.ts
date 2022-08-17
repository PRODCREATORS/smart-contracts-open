import { expect }  from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat"
import { Pauser} from "../typechain-types/contracts";
import { PausableMock } from "../typechain-types/contracts/test/PausableMock";

describe("Pauser", function () {
    let pauser: Pauser
    let owner: Signer;
    let pausableContracts: PausableMock[] = [];
    
    before(async function () {
        const PauserFactory = await ethers.getContractFactory("Pauser");
        const PausableMockFactory = await ethers.getContractFactory("PausableMock");
        owner = (await ethers.getSigners())[0];
        for (let i = 0; i < 3; i++) {
            let pausableMock = (await PausableMockFactory.deploy()) as PausableMock;
            pausableContracts.push(pausableMock);
        }
        pauser = (await PauserFactory.deploy(pausableContracts.map(contract => contract.address))) as Pauser;
        for (let i = 0; i < 3; i++) {
            await pausableContracts[i].addPauser(pauser.address);
        }
    });

    it("Grant pauser role", async function () {
        await pauser.grantRole(pauser.PAUSER_ROLE(), owner.getAddress());
    });

    it("Pause", async function () {
        await pauser.pause();
        for (let i = 0; i < 3; i++) {
            expect(await pausableContracts[i].paused()).to.equal(true);
        }
    });
});