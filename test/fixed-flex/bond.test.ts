import {deployIssuer, deployVault, issueBond, revertOperation} from "./utils/deploy";
import {ethers} from "hardhat";
import {BondFeeConstants, OperationCodes, OperationFailed, OwnableUnauthorizedAccount} from "./utils/constants";
import type {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {expect} from "chai";
import {ContractRunner} from "ethers";
import {Bond__factory, CustomToken__factory, Issuer__factory} from "../../typechain-types";
import {mineBlocks} from "./utils/block";
import {generateWallet} from "./utils/address";

describe("Bond", () => {


    let issuerAddress: string
    let tokenAddress: string;
    let deployer: HardhatEthersSigner;
    const bondConfig = {
        totalBonds: BigInt(100),
        maturityPeriodInBlocks: BigInt(10),
        purchaseAmount: BigInt(10 * 1e18),
        payoutAmount: BigInt(15 * 1e18)
    }

    function getBond(bondAddress: string, runner?: ContractRunner | null | undefined) {
        if (!bondAddress) throw Error("NOT INITIATED");
        return Bond__factory.connect(bondAddress, runner || deployer)
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
        await issuer.changeVault(vault.target);

        const token = await ethers.deployContract("CustomToken", [])
        tokenAddress = token.target.toString();

        const signers = await ethers.getSigners();
        deployer = signers[0];

    })

    it("Purchase", async () => {
        const bond = await deployBond();
        const token = getToken();

        // ERC20InsufficientAllowance
        await revertOperation(bond, bond.purchase(BigInt(1), ethers.ZeroAddress))

        await token.approve(bond.target.toString(), BigInt(30) * bondConfig.purchaseAmount);

        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), generateWallet().address)
        const lifecycle = await bond.lifecycle();
        expect(lifecycle.purchased).to.be.equal(BigInt(5))

        await revertOperation(bond, bond.purchase(BigInt(150), ethers.ZeroAddress), OperationFailed, OperationCodes.ACTION_INVALID);
    })

    it("Redeem", async () => {
        const bond = await deployBond();
        const token = getToken();

        await token.approve(bond.target.toString(), BigInt(30) * bondConfig.purchaseAmount);

        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)

        // INSUFFICIENT_PAYOUT
        const promiseI = bond.redeem([BigInt(0)], BigInt(1), false)
        await revertOperation(bond, promiseI, OperationFailed, OperationCodes.INSUFFICIENT_PAYOUT)
        await token.transfer(bond.target, BigInt(4) * bondConfig.payoutAmount);

        // REDEEM_BEFORE_MATURITY
        const promiseR = bond.redeem([BigInt(0)], BigInt(1), false)
        await revertOperation(bond, promiseR, OperationFailed, OperationCodes.REDEEM_BEFORE_MATURITY)

        // CAPITULATION_REDEEM
        await bond.redeem([BigInt(3)], BigInt(1), true);

        await mineBlocks(bondConfig.maturityPeriodInBlocks);
        await bond.redeem([BigInt(0)], BigInt(1), false);

        const lifecycle = await bond.lifecycle();
        expect(lifecycle.redeemed).to.be.equal(BigInt(2));

        //ACTION_INVALID
        const promiseA = bond.redeem([BigInt(1)], BigInt(2), false);
        await revertOperation(bond, promiseA, OperationFailed, OperationCodes.ACTION_INVALID)
    })

    it("Withdraw Excess Payout", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond();
        const token = getToken();

        // ONLY_OWNER
        const promiseO = bond.connect(random).withdrawExcessPayout()
        await revertOperation(bond, promiseO, OwnableUnauthorizedAccount);

        // ACTION_BLOCKED
        const promiseA = bond.withdrawExcessPayout()
        await revertOperation(bond, promiseA, OperationFailed, OperationCodes.ACTION_BLOCKED)

        await token.transfer(bond.target, (bondConfig.totalBonds + BigInt(10)) * bondConfig.payoutAmount);
        await bond.withdrawExcessPayout();
    })

    it("Settle", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()
        const token = getToken();

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).settle(), OwnableUnauthorizedAccount)

        // INSUFFICIENT_PAYOUT
        await revertOperation(bond, bond.settle(), OperationFailed, OperationCodes.INSUFFICIENT_PAYOUT)

        await token.transfer(bond.target, bondConfig.payoutAmount * bondConfig.totalBonds)
        await bond.settle();
    })

    it("Update Bond Supply", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()
        const token = getToken();

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).updateBondSupply(1), OwnableUnauthorizedAccount)

        // ACTION_BLOCKED for lifecycleTmp.purchased > totalBonds
        await token.approve(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);
        await bond.purchase(BigInt(10), ethers.ZeroAddress);
        await revertOperation(bond, bond.updateBondSupply(BigInt(1)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await token.transfer(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);
        await bond.settle()

        // lifecycleTmp.isSettled && totalBonds > lifecycleTmp.totalBonds
        await revertOperation(bond, bond.updateBondSupply(BigInt(1) + BigInt(bondConfig.totalBonds)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        bondConfig.totalBonds = BigInt(50)
        await bond.updateBondSupply(BigInt(50));
    })

    it("Decrease Maturity Period", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).decreaseMaturityPeriod(1), OwnableUnauthorizedAccount)

        // maturityPeriodInBlocks >= lifecycleTmp.maturityPeriodInBlocks ACTION_BLOCKED
        await revertOperation(bond, bond.decreaseMaturityPeriod(BigInt(4000)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await bond.decreaseMaturityPeriod(bondConfig.maturityPeriodInBlocks - BigInt(1));
    })

    it("Get Settled Purchase Details", async () => {
        const bond = await deployBond()
        const token = getToken();

        await revertOperation(bond, bond.getSettledPurchaseDetails(), OperationFailed, OperationCodes.ACTION_BLOCKED)
        await token.transfer(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);
        await bond.settle();
        await token.approve(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);
        await bond.purchase(bondConfig.totalBonds, ethers.ZeroAddress)

        await bond.getSettledPurchaseDetails();
    })


    it("URI", async () => {
        const bond = await deployBond();
        const uri = await bond.uri(0);
        expect(uri).to.include("https://storage.amet.finance/contracts/")
    })
})
