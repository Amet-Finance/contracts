import {deployIssuer, deployVault, revertOperation} from "./utils/deploy";
import {expect} from "chai";
import {ethers} from "hardhat";
import {OperationCodes, OperationFailed} from "./utils/constants";

describe("Vault", () => {

    let issuerAddress: string;

    before(async () => {
        const issuer = await deployIssuer()
        issuerAddress = issuer.target.toString();
    })

    it("Deploy", async () => {
        const vault = await deployVault(issuerAddress);
        expect(ethers.isAddress(vault.target.toString())).to.be.equal(true);
    })

    it("Initialize Bond", async () => {
        const vault = await deployVault(issuerAddress);
        await revertOperation(vault, vault.initializeBond(ethers.ZeroAddress), OperationFailed, OperationCodes.CALLER_NOT_ISSUER_CONTRACT)
    })
})
