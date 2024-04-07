import {deployIssuer, deployToken, deployVault, issueBond, revertOperation} from "./utils/deploy";
import {ethers} from "hardhat";
import {OperationCodes, OperationFailed, OwnableUnauthorizedAccount} from "./utils/constants";
import type {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {expect} from "chai";
import {ContractRunner} from "ethers";
import {CustomToken__factory, Issuer__factory, Vault__factory} from "../../typechain-types";
import {mineBlocks} from "./utils/block";
import {generateWallet} from "./utils/address";

describe("Bond", () => {
    let issuerAddress: string
    let tokenAddress: string;
    let deployer: HardhatEthersSigner;
    const bondConfig1 = {
        totalBonds: BigInt(100),
        maturityPeriodInBlocks: BigInt(10),
        purchaseAmount: BigInt(10 * 1e18),
        payoutAmount: BigInt(15 * 1e18)
    }

    const bondConfig = {
        isin: 'US9VL26IA9N0',
        name: 'AMazon 2030',
        symbol: 'AMZ30',
        currency: generateWallet().address,
        denomination: BigInt(100),
        issueVolume: BigInt(10000),
        couponRate: BigInt(200),
        issueDate: BigInt(0),
        maturityDate: BigInt(10),
        issuePrice: BigInt(10 * 1e18),
        payoutCurrency: generateWallet().address,
        payoutAmount: BigInt(15 * 1e18)
    }

    function getToken(runner?: ContractRunner | null | undefined) {
        if (!tokenAddress) throw Error("NOT INITIATED");
        return CustomToken__factory.connect(tokenAddress, runner || deployer)
    }

    async function deployBond() {
        return issueBond(issuerAddress, bondConfig, deployer)
    }


    before(async () => {
        const issuer = await deployIssuer();
        issuerAddress = issuer.target.toString()

        const vault = await deployVault(issuer.target);
        await issuer.changeVault(vault.target);

        const token = await deployToken()
        tokenAddress = token.target.toString();

        bondConfig.currency = tokenAddress;

        const signers = await ethers.getSigners();
        deployer = signers[0];

    })

    it.only("Purchase", async () => {
        const [signer] = await ethers.getSigners();
        const issuerContract = Issuer__factory.connect(issuerAddress, signer);
        const valutAddress = await issuerContract.vault();
        const valutContract = Vault__factory.connect(valutAddress, signer);

        const bond = await deployBond();
        const token = getToken();

        // ERC20InsufficientAllowance
        await revertOperation(bond, bond.purchase(BigInt(1), ethers.ZeroAddress));

        let totalBonds = bondConfig.issueVolume / bondConfig.denomination;

        await token.approve(bond.target.toString(), totalBonds * bondConfig.issuePrice);
        await revertOperation(bond, bond.purchase(totalBonds + BigInt(1), ethers.ZeroAddress), OperationFailed, OperationCodes.ACTION_INVALID)

        await bond.purchase(BigInt(0), ethers.ZeroAddress) // allow purchase with 0
        await bond.purchase(BigInt(1), signer.address);
        await bond.purchase(BigInt(50), ethers.ZeroAddress)

        // REFERRAL FOR SIGNER 0
        const signerReferrerData = await valutContract.getReferrerData(bond.target, signer.address);
        expect(signerReferrerData.quantity).to.be.equal(BigInt(0));

        // PURCHASE MORE THAN CAN BE
        await revertOperation(bond, bond.purchase(totalBonds, ethers.ZeroAddress))

        // REFERRAL LOGIC HERE
        const referrer = generateWallet();
        await bond.purchase(BigInt(1), referrer.address);
        const referrerData = await valutContract.getReferrerData(bond.target, referrer.address);
        expect(referrerData.quantity).to.be.equal(BigInt(1));

        const lifecycle = await bond.lifecycle();
        expect(lifecycle.purchased).to.be.equal(BigInt(52));
    })

    it("Redeem", async () => {
        const bond = await deployBond();
        const token = getToken();

        let totalBonds = bondConfig.issueVolume / bondConfig.denomination;

        await token.approve(bond.target.toString(), BigInt(30) * bondConfig.issuePrice);

        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)
        await bond.purchase(BigInt(1), ethers.ZeroAddress)

        // INSUFFICIENT_PAYOUT
        const promiseI = bond.redeem([BigInt(0)], BigInt(1), false)
        await revertOperation(bond, promiseI, OperationFailed, OperationCodes.INSUFFICIENT_PAYOUT)
        await token.transfer(bond.target, totalBonds * bondConfig.payoutAmount);

        // REDEEM_BEFORE_MATURITY
        const promiseR = bond.redeem([BigInt(0)], BigInt(1), false)
        await revertOperation(bond, promiseR, OperationFailed, OperationCodes.REDEEM_BEFORE_MATURITY)

        // CAPITULATION_REDEEM WITH LESS PAYOUT AS IT's NOT MATURE
        await bond.redeem([BigInt(3)], BigInt(1), true);

        // MINE BLOCK TO MAKE BONDS MATURE
        await mineBlocks(bondConfig.maturityDate);

        // CAPITULATION_REDEEM ON MATURE BONDS
        const capitulationCount = BigInt(1)
        const capitulationTx = await bond.redeem([BigInt(6)], capitulationCount, true);
        const txReceipt = await ethers.provider.getTransactionReceipt(capitulationTx.hash);

        if (!txReceipt?.logs) throw Error("Missing Logs");

        for (const log of txReceipt.logs) {
            const decodedData = token.interface.parseLog({
                topics: [...log.topics],
                data: log.data
            });
            if (decodedData?.name === "Transfer") {
                expect(decodedData.args.value).to.be.equal(capitulationCount * bondConfig.payoutAmount);
            }
        }

        await bond.redeem([BigInt(0)], BigInt(1), false);

        const lifecycle = await bond.lifecycle();
        expect(lifecycle.redeemed).to.be.equal(BigInt(3));

        //ACTION_INVALID
        const promiseA = bond.redeem([BigInt(1)], BigInt(2), false);
        await revertOperation(bond, promiseA, OperationFailed, OperationCodes.ACTION_INVALID)
    })

    it("Withdraw Excess Payout", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond();
        const token = getToken();

        let totalBonds = bondConfig.issueVolume / bondConfig.denomination;

        // ONLY_OWNER
        const promiseO = bond.connect(random).withdrawExcessPayout()
        await revertOperation(bond, promiseO, OwnableUnauthorizedAccount);

        // ACTION_BLOCKED
        const promiseA = bond.withdrawExcessPayout()
        await revertOperation(bond, promiseA, OperationFailed, OperationCodes.ACTION_BLOCKED)

        await token.transfer(bond.target, (totalBonds + BigInt(10)) * bondConfig.payoutAmount);
        await bond.withdrawExcessPayout();
    })

    it("Settle", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()
        const token = getToken();

        let totalBonds = bondConfig.issueVolume / bondConfig.denomination;

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).settle(), OwnableUnauthorizedAccount)

        // INSUFFICIENT_PAYOUT
        await revertOperation(bond, bond.settle(), OperationFailed, OperationCodes.INSUFFICIENT_PAYOUT)

        await token.transfer(bond.target, bondConfig.payoutAmount * totalBonds)
        await bond.settle();
    })

    it("Update Bond Supply", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()
        const token = getToken();
        let totalBonds = bondConfig.issueVolume / bondConfig.denomination; 

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).updateBondSupply(1), OwnableUnauthorizedAccount)

        // ACTION_BLOCKED for lifecycleTmp.purchased > totalBonds
        await token.approve(bond.target, totalBonds * bondConfig.payoutAmount);
        await bond.purchase(BigInt(10), ethers.ZeroAddress);
        await revertOperation(bond, bond.updateBondSupply(BigInt(1)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await token.transfer(bond.target, totalBonds * bondConfig.payoutAmount);
        await bond.settle()

        // lifecycleTmp.isSettled && totalBonds > lifecycleTmp.totalBonds
        await revertOperation(bond, bond.updateBondSupply(BigInt(1) + BigInt(totalBonds)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        bondConfig.issueVolume = BigInt(5000)
        await bond.updateBondSupply(BigInt(50));
    })

    it("Decrease Maturity Period", async () => {
        const [_, random] = await ethers.getSigners();
        const bond = await deployBond()

        // ONLY_OWNER
        await revertOperation(bond, bond.connect(random).decreaseMaturityPeriod(1), OwnableUnauthorizedAccount)

        // maturityPeriodInBlocks >= lifecycleTmp.maturityPeriodInBlocks ACTION_BLOCKED
        await revertOperation(bond, bond.decreaseMaturityPeriod(BigInt(4000)), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await bond.decreaseMaturityPeriod(bondConfig.maturityDate - BigInt(1));
    })

    it("Ownership update, transfer, re-announce", async () => {
        const [issuer, random] = await ethers.getSigners();
        const bond = await deployBond()

        await revertOperation(bond, bond.renounceOwnership(), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await bond.transferOwnership(random.address);
        const pendingOwner = await bond.pendingOwner();
        expect(pendingOwner).to.be.equal(random.address);

        await bond.connect(random).acceptOwnership()
        const owner = await bond.owner()
        expect(owner).to.be.equal(random.address);


        // // maturityPeriodInBlocks >= lifecycleTmp.maturityPeriodInBlocks ACTION_BLOCKED
        // await revertOperation(bond, bond.decreaseMaturityPeriod(BigInt(4000)), OperationFailed, OperationCodes.ACTION_BLOCKED)
        //
        // await bond.decreaseMaturityPeriod(bondConfig.maturityPeriodInBlocks - BigInt(1));
    })

    it("Get Purchase Details", async () => {
        const bond = await deployBond()
        await bond.getPurchaseDetails();
    })
});