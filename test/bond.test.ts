import {deployIssuer, deployVault} from "./utils/deploy";
import {ethers} from "hardhat";
// import {Bond__factory, CustomToken__factory} from "../typechain-types";
import {BondFeeConstants} from "./utils/constants";
import type {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {expect} from "chai";
import {ContractRunner} from "ethers";
import {Bond__factory, CustomToken__factory} from "../typechain-types";
import {mineBlocks} from "./utils/block";

describe("Bond", () => {


    let bondAddress: string;
    let tokenAddress: string;
    let deployer: HardhatEthersSigner;
    const bondConfig = {
        totalBonds: BigInt(100),
        maturityPeriodInBlocks: BigInt(10),
        purchaseAmount: BigInt(10 * 1e18),
        payoutAmount: BigInt(15 * 1e18)
    }

    function getBond(runner?: ContractRunner | null | undefined) {
        if (!bondAddress) throw Error("NOT INITIATED");
        return Bond__factory.connect(bondAddress, runner || deployer)
    }

    function getToken(runner?: ContractRunner | null | undefined) {
        if (!tokenAddress) throw Error("NOT INITIATED");
        return CustomToken__factory.connect(tokenAddress, runner || deployer)
    }


    before(async () => {
        const issuer = await deployIssuer();
        const vault = await deployVault(issuer.target);
        await issuer.changeVault(vault.target);
        const token = await ethers.deployContract("CustomToken", [])
        const bondTransaction = await issuer.issue(
            bondConfig.totalBonds,
            bondConfig.maturityPeriodInBlocks,
            token.target,
            bondConfig.purchaseAmount,
            token.target,
            bondConfig.payoutAmount, {value: BondFeeConstants.initialIssuanceFee});
        const txRecipient = await ethers.provider.getTransactionReceipt(bondTransaction.hash);
        if (txRecipient?.logs) {
            for (const log of txRecipient.logs) {
                const decodedData = issuer.interface.parseLog({
                    topics: [...log.topics],
                    data: log.data
                });
                if (decodedData?.name === "BondIssued") {
                    bondAddress = decodedData.args.bondAddress
                }
            }
        }
        tokenAddress = token.target.toString();
        const signers = await ethers.getSigners();
        deployer = signers[0];
    })

    it("Purchase", async () => {
        const bond = getBond();
        const token = getToken();

        await expect(bond.purchase(BigInt(1), ethers.ZeroAddress)).to.be.reverted;

        await token.approve(bond.target.toString(), BigInt(30) * bondConfig.purchaseAmount);

        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        const lifecycle = await bond.lifecycle();
        expect(lifecycle.purchased).to.be.equal(BigInt(5))

        await expect(bond.purchase(BigInt(150), ethers.ZeroAddress)).to.be.reverted;
    })

    it("Redeem", async () => {
        const bond = getBond();
        const token = getToken();

        // INSUFFICIENT_PAYOUT
        await expect(bond.redeem([BigInt(0)], BigInt(1), false)).to.be.reverted;
        await token.transfer(bond.target, BigInt(4) * bondConfig.payoutAmount);

        // REDEEM_BEFORE_MATURITY
        await expect(bond.redeem([BigInt(0)], BigInt(1), false)).to.be.reverted;

        // CAPITULATION_REDEEM
        await bond.redeem([BigInt(3)], BigInt(1), true);

        await mineBlocks(bondConfig.maturityPeriodInBlocks);
        await bond.redeem([BigInt(0)], BigInt(1), false);

        const lifecycle = await bond.lifecycle();
        expect(lifecycle.redeemed).to.be.equal(BigInt(2));

        //ACTION_INVALID
        await expect(bond.redeem([BigInt(1)], BigInt(2), false)).to.be.reverted;
    })

    it("Settle", async () => {
        const [_, random] = await ethers.getSigners();
        const bondRandom = getBond(random);
        const token = getToken();

        await expect(bondRandom.settle()).to.be.reverted;

        const bond = getBond()
        // INSUFFICIENT_PAYOUT
        await expect(bond.settle()).to.be.reverted;
        await token.transfer(bond.target, bondConfig.payoutAmount * bondConfig.totalBonds)

        await bond.settle();
    })

    it("URI", async () => {
        const bond = getBond();
        const uri = await bond.uri(0);
        expect(uri).to.include("https://storage.amet.finance/contracts/")
    })
})
