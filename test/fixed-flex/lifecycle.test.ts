import {deployIssuer, deployVault, issueBond} from "./utils/deploy";
import {ethers} from "hardhat";

const bondConfig = {
    totalBonds: BigInt(100),
    maturityPeriodInBlocks: BigInt(10),
    purchaseAmount: BigInt(10 * 1e18),
    payoutAmount: BigInt(15 * 1e18)
}

describe("Lifecycle", () => {
    it('General Lifecycle ', async () => {
        const [deployer] = await ethers.getSigners();
        const issuer = await deployIssuer();
        const valut = await deployVault(issuer.target);
        const token = await ethers.deployContract("CustomToken", [])
        const bond = issueBond(issuer.target.toString(), token.target.toString(), bondConfig, deployer)

    });
})
