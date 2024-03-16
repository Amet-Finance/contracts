import {ethers} from "hardhat";
import {deployIssuer, deployToken, deployVault, issueBond} from "./utils/deploy";
import {BondFeeConstants} from "./utils/constants";
import {expect} from "chai";
import type {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ContractRunner} from "ethers";
import {CustomToken__factory, Vault__factory} from "../../typechain-types";
import {mineBlocks} from "./utils/block";

const bondConfig = {
    totalBonds: BigInt(100),
    maturityPeriodInBlocks: BigInt(10),
    purchaseAmount: BigInt(10 * 1e18),
    payoutAmount: BigInt(15 * 1e18)
}

describe("Detailed Purchase Actions", () => {

    let issuerAddress: string;
    let vaultAddress: string;
    let tokenAddress: string;
    let deployer: HardhatEthersSigner;
    const bondConfig = {
        totalBonds: BigInt(100),
        maturityPeriodInBlocks: BigInt(10),
        purchaseAmount: BigInt(10 * 1e18),
        payoutAmount: BigInt(15 * 1e18)
    }

    function getToken(runner?: ContractRunner | null | undefined) {
        if (!tokenAddress) throw Error("NOT INITIATED");
        return CustomToken__factory.connect(tokenAddress, runner || deployer)
    }

    async function deployBond() {
        return issueBond(issuerAddress, tokenAddress, bondConfig, deployer)
    }


    before(async () => {
        const issuer = await deployIssuer();
        issuerAddress = issuer.target.toString()

        const vault = await deployVault(issuer.target);
        vaultAddress = vault.target.toString();
        await issuer.changeVault(vault.target);

        const token = await deployToken()
        tokenAddress = token.target.toString();

        const signers = await ethers.getSigners();
        deployer = signers[0];

    })

    it("Purchase Fee and Referral Rewards Calculations", async () => {
        const [signer, referrer] = await ethers.getSigners();

        const tokenContract = getToken();
        const vaultContract = Vault__factory.connect(vaultAddress, signer);
        const bondContract = await deployBond()

        const purchaseQuantity = bondConfig.totalBonds;

        await tokenContract.approve(bondContract.target.toString(), purchaseQuantity * bondConfig.purchaseAmount);
        const tx = await bondContract.purchase(purchaseQuantity, referrer.address);

        if (!tx.blockNumber) throw Error("Block is missing");

        const blockNumber = await bondContract.purchaseBlocks(BigInt(0))
        expect(blockNumber).to.be.equal(BigInt(tx.blockNumber));

        const balance = await bondContract.balanceOf(signer.address, BigInt(0))
        expect(balance).to.be.equal(purchaseQuantity);


        const vaultPurchaseFee = (purchaseQuantity * bondConfig.purchaseAmount) * BondFeeConstants.purchaseRate / BigInt(1000);
        const vaultBalanceBefore = await tokenContract.balanceOf(vaultContract.target.toString());
        expect(vaultPurchaseFee).to.be.equal(vaultBalanceBefore);

        await vaultContract.connect(referrer).claimReferralRewards(bondContract.target.toString());

        const referrerRewards = (purchaseQuantity * bondConfig.purchaseAmount) * BondFeeConstants.referrerRewardRate / BigInt(1000);
        const vaultPurchaseFeeDeductedReferrer = vaultPurchaseFee - referrerRewards;
        const vaultBalanceAfter = await tokenContract.balanceOf(vaultContract.target.toString());
        expect(vaultPurchaseFeeDeductedReferrer).to.be.equal(vaultBalanceAfter);

        const referrerBalance = await tokenContract.balanceOf(referrer.address);
        expect(referrerBalance).to.be.equal(referrerRewards);
    })

    it("Capitulation Redeem Calculations", async () => {
        const [signer, referrer] = await ethers.getSigners();

        const tokenContract = getToken();
        const vaultContract = Vault__factory.connect(vaultAddress, signer);
        const bondContract = await deployBond()

        const purchaseQuantity = bondConfig.totalBonds;

        await tokenContract.approve(bondContract.target.toString(), purchaseQuantity * bondConfig.purchaseAmount);
        await tokenContract.transfer(bondContract.target.toString(), purchaseQuantity * bondConfig.payoutAmount);

        const purchaseTx = await bondContract.purchase(purchaseQuantity, referrer.address);

        // MINE HALF AND CAPITULATE
        await mineBlocks(BigInt(1));

        const transaction = await bondContract.redeem([BigInt(0)], purchaseQuantity, true);
        const txRecipient = await ethers.provider.getTransactionReceipt(transaction.hash);

        const purchaseBlock = purchaseTx.blockNumber;
        if (!purchaseBlock) throw Error("MISSING BLOCK");

        const currentBlock = await ethers.provider.getBlockNumber();
        const blocksPassed = BigInt(currentBlock) - BigInt(purchaseBlock);

        const totalPayout = purchaseQuantity * bondConfig.payoutAmount;
        const capitulationPayout = blocksPassed * totalPayout / bondConfig.maturityPeriodInBlocks;
        const intendedPayout = capitulationPayout - (capitulationPayout * BondFeeConstants.earlyRedemptionRate / BigInt(1000))

        if (!txRecipient?.logs) throw Error("FAILED");

        for (const log of txRecipient?.logs) {
            const decodedData = tokenContract.interface.parseLog({
                topics: [...log.topics],
                data: log.data
            });
            if (decodedData?.name === "Transfer") {
                expect(decodedData.args.value).to.be.equal(intendedPayout)
            }
        }
    })
})
