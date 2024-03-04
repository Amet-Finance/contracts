import {ethers} from "hardhat";
import {expect} from "chai"
import {deployIssuer, deployVault, revertOperation} from "./utils/deploy";
import {generateWallet} from "./utils/address";
import {BondFeeConstants, OperationCodes, OperationFailed, OwnableUnauthorizedAccount} from "./utils/constants";

describe("Issuer", () => {
    it("Deploying", async () => {
        const contract = await deployIssuer()
        expect(ethers.isAddress(contract.target)).to.be.equal(true)
    })

    it("Pausing", async () => {
        const [_, randomAddress] = await ethers.getSigners();
        const contract = await deployIssuer()
        const isPaused = await contract.isPaused()
        if (isPaused) {
            throw Error("Invalid paused state")
        }
        await contract.changePausedState(true)
        const isPausedAfterChange = await contract.isPaused()
        expect(isPausedAfterChange).to.equal(true);

        await revertOperation(contract, contract.connect(randomAddress).changePausedState(true), OwnableUnauthorizedAccount)
    })

    it("Change Vault", async () => {
        const [_, randomAddress] = await ethers.getSigners();
        const contract = await deployIssuer()

        const vaultAddress = generateWallet().address;
        await contract.changeVault(vaultAddress);
        const vault = await contract.vault()

        await revertOperation(contract, contract.connect(randomAddress).changeVault(vaultAddress), OwnableUnauthorizedAccount)
        expect(vault).to.equal(vaultAddress);
    })

    it("Issuing Bonds", async () => {
        const contract = await deployIssuer()

        const totalBonds = BigInt(100)
        const maturityInBlocks = BigInt(20);
        const purchaseToken = generateWallet().address;
        const purchaseAmount = BigInt(100)
        const payoutToken = generateWallet().address
        const payoutAmount = BigInt(150)

        await expect(contract.issue(totalBonds, maturityInBlocks, purchaseToken, purchaseAmount, payoutToken, payoutAmount, {value: BondFeeConstants.initialIssuanceFee})).to.be.reverted;

        const vault = await deployVault(contract.target)
        await contract.changeVault(vault.target);

        await contract.changePausedState(true);
        await expect(contract.issue(totalBonds, maturityInBlocks, purchaseToken, purchaseAmount, payoutToken, payoutAmount, {value: BondFeeConstants.initialIssuanceFee})).to.be.reverted;
        await contract.changePausedState(false);

        await expect(contract.issue(totalBonds, maturityInBlocks, purchaseToken, purchaseAmount, payoutToken, payoutAmount, {value: BigInt(0)})).to.be.reverted;

        await contract.issue(totalBonds, maturityInBlocks, purchaseToken, purchaseAmount, payoutToken, payoutAmount, {value: BondFeeConstants.initialIssuanceFee})
    })

    it("Renounce Ownership", async () => {
        const [_, random] = await ethers.getSigners();
        const contract = await deployIssuer()
        await expect(contract.renounceOwnership()).to.be.reverted;

        await expect(contract.connect(random).renounceOwnership()).to.be.reverted;
    })
})
