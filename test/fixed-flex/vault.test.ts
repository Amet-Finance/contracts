import {deployIssuer, deployVault, issueBond, revertOperation} from "./utils/deploy";
import {expect} from "chai";
import {ethers} from "hardhat";
import {BondFeeConstants, OperationCodes, OperationFailed, OwnableUnauthorizedAccount} from "./utils/constants";
import {BondConfig} from "./utils/types";
import {Vault__factory} from "../../typechain-types";
import {generateWallet} from "./utils/address";

describe("Vault", () => {

    let issuerAddress: string;
    let vaultAddress: string;
    const bondConfig: BondConfig = {
        totalBonds: BigInt(50),
        maturityPeriodInBlocks: BigInt(10),
        payoutAmount: BigInt(50 * 1e18),
        purchaseAmount: BigInt(55 * 1e18),
    }

    before(async () => {
        const issuer = await deployIssuer()
        const vault = await deployVault(issuer.target);
        await issuer.changeVault(vault.target);

        issuerAddress = issuer.target.toString();
        vaultAddress = vault.target.toString();
    })

    it("Deploy", async () => {
        const vault = await deployVault(issuerAddress);
        expect(ethers.isAddress(vault.target.toString())).to.be.equal(true);
    })

    it("Initialize Bond", async () => {
        const vault = await deployVault(issuerAddress);
        await revertOperation(vault, vault.initializeBond(ethers.ZeroAddress), OperationFailed, OperationCodes.CALLER_NOT_ISSUER_CONTRACT)
    })

    it("Record Referral Purchase", async () => {
        const [deployer] = await ethers.getSigners();
        const token = await ethers.deployContract("CustomToken", []);

        const bondConfig: BondConfig = {
            totalBonds: BigInt(50),
            maturityPeriodInBlocks: BigInt(10),
            payoutAmount: BigInt(50 * 1e18),
            purchaseAmount: BigInt(55 * 1e18),
        }
        const bond = await issueBond(issuerAddress, token.target.toString(), bondConfig, deployer)

        await token.approve(bond.target, bondConfig.totalBonds * bondConfig.purchaseAmount);
        const randomAddress = generateWallet().address
        await bond.purchase(BigInt(10), randomAddress);
        await bond.purchase(BigInt(10), deployer.address);


        const vault = Vault__factory.connect(vaultAddress, deployer);
        const referrerDataDeployer = await vault.getReferrerData(bond.target, deployer.address);
        const referrerDataRandom = await vault.getReferrerData(bond.target, randomAddress);

        expect(referrerDataDeployer.quantity).to.equal(0)
        expect(referrerDataRandom.quantity).to.equal(10n)
    })

    it("Claim Referral Rewards", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, referrer);
        const token = await ethers.deployContract("CustomToken", []);

        const bond = await issueBond(issuerAddress, token.target.toString(), bondConfig, deployer)

        await token.approve(bond.target, bondConfig.totalBonds * bondConfig.purchaseAmount);

        // QUANTITY_0
        await revertOperation(bond, vault.claimReferralRewards(bond.target), OperationFailed, OperationCodes.ACTION_BLOCKED)

        await bond.purchase(bondConfig.totalBonds, referrer.address);
        await token.transfer(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);

        // NOT SETTLED YET
        await revertOperation(vault, vault.claimReferralRewards(bond.target), OperationFailed, OperationCodes.ACTION_BLOCKED)
        await bond.settle();


        await vault.claimReferralRewards(bond.target);
        const balance = await token.balanceOf(referrer.address);
        expect(balance).to.be.greaterThan(BigInt(0))


        // isRepaid
        await revertOperation(vault, vault.claimReferralRewards(bond.target), OperationFailed, OperationCodes.ACTION_BLOCKED)
    })

    it("Update Initial Fees", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, deployer);

        await revertOperation(vault, vault.updateBondFeeDetails(ethers.ZeroAddress, BigInt(10), BigInt(10), BigInt(11)), OperationFailed, OperationCodes.ACTION_BLOCKED)
        await revertOperation(vault, vault.connect(referrer).updateBondFeeDetails(ethers.ZeroAddress, BigInt(10), BigInt(10), BigInt(5)), OwnableUnauthorizedAccount)
        await vault.updateBondFeeDetails(ethers.ZeroAddress, BondFeeConstants.purchaseRate, BondFeeConstants.earlyRedemptionRate, BondFeeConstants.referrerRewardRate);
    })

    it("Update Issuance Fee", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, deployer);

        await revertOperation(vault, vault.connect(referrer).updateIssuanceFee(BigInt(10)), OwnableUnauthorizedAccount)
        await vault.updateIssuanceFee(BigInt(10));
        await vault.updateIssuanceFee(BondFeeConstants.initialIssuanceFee);
    })

    it("Update Bond Fee Details", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, deployer);

        await revertOperation(vault, vault.connect(referrer).updateBondFeeDetails(ethers.ZeroAddress, BigInt(10), BigInt(10), BigInt(9)), OwnableUnauthorizedAccount);

        const token = await ethers.deployContract("CustomToken", []);
        const bond = await issueBond(issuerAddress, token.target.toString(), bondConfig, deployer);

        await revertOperation(vault, vault.updateBondFeeDetails(bond.target, BigInt(10), BigInt(10), BigInt(11)), OperationFailed, OperationCodes.ACTION_BLOCKED);
        await vault.updateBondFeeDetails(bond.target, BigInt(10), BigInt(10), BigInt(5))
    })

    it("Update Restriction Status", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, deployer);

        await revertOperation(vault, vault.connect(referrer).updateRestrictionStatus(ethers.ZeroAddress, true), OwnableUnauthorizedAccount);
        await vault.updateRestrictionStatus(ethers.ZeroAddress, true);

        const status = await vault.isAddressRestricted(ethers.ZeroAddress);
        expect(status).to.be.equal(true);

        // RESTRICTED ADDRESS
        await vault.updateRestrictionStatus(deployer.address, true);
        await revertOperation(vault, vault.claimReferralRewards(ethers.ZeroAddress), OperationFailed, OperationCodes.ACTION_BLOCKED);
    })

    it("Withdraw", async () => {
        const [deployer, referrer] = await ethers.getSigners();
        const vault = Vault__factory.connect(vaultAddress, deployer);

        const token = await ethers.deployContract("CustomToken", []);
        const bond = await issueBond(issuerAddress, token.target.toString(), bondConfig, deployer);

        await token.approve(bond.target, bondConfig.totalBonds * bondConfig.purchaseAmount);
        await bond.purchase(bondConfig.totalBonds, referrer.address);


        const balanceETH = await ethers.provider.getBalance(vault.target);
        const balanceTOKEN = await token.balanceOf(vault.target);

        // WITHDRAW ETHER OWNER INVALID
        await revertOperation(vault, vault.connect(referrer).withdraw(ethers.ZeroAddress, deployer.address, balanceETH), OwnableUnauthorizedAccount)

        // WITHDRAW ETHER INVALID ADDRESS
        await revertOperation(vault, vault.withdraw(ethers.ZeroAddress, ethers.ZeroAddress, balanceETH), OperationFailed, OperationCodes.ADDRESS_INVALID)


        // WITHDRAW ETHER REVERT ADDRESS
        await revertOperation(vault, vault.withdraw(ethers.ZeroAddress, issuerAddress, balanceETH), OperationFailed, OperationCodes.ACTION_INVALID)


        // WITHDRAW TOKEN INVALID AMOUNT
        await revertOperation(vault, vault.withdraw(token.target, referrer.address, balanceTOKEN * BigInt(2)))


        await vault.withdraw(token.target, referrer.address, balanceTOKEN / BigInt(2))
        await vault.withdraw(ethers.ZeroAddress, referrer.address, balanceETH / BigInt(2))
    })

    it("Issued bond behaviour after changing vault for purchase", async () => {
        const [deployer, random] = await ethers.getSigners();
        const issuer = await deployIssuer();
        const token = await ethers.deployContract("CustomToken", [])
        const vaultOriginal = await deployVault(issuer.target);
        await issuer.changeVault(vaultOriginal.target);

        const bond = await issueBond(issuer.target.toString(), token.target.toString(), bondConfig, deployer);

        await token.approve(bond.target, bondConfig.purchaseAmount * bondConfig.totalBonds);
        await bond.purchase(BigInt(1), ethers.ZeroAddress);

        const vaultChanged = await deployVault(issuer.target);
        await issuer.changeVault(vaultChanged.target);

        await revertOperation(bond, bond.purchase(BigInt(1), ethers.ZeroAddress), OperationFailed, OperationCodes.CONTRACT_NOT_INITIATED);

        await vaultChanged.updateBondFeeDetails(bond.target, BondFeeConstants.purchaseRate, BondFeeConstants.earlyRedemptionRate, BondFeeConstants.referrerRewardRate);
        await bond.purchase(BigInt(1), ethers.ZeroAddress);
    })

    it("Issued bond behaviour after changing vault for claiming referral rewards", async () => {
        const [deployer, random] = await ethers.getSigners();
        const issuer = await deployIssuer();
        const token = await ethers.deployContract("CustomToken", [])
        const vaultOriginal = await deployVault(issuer.target);
        await issuer.changeVault(vaultOriginal.target);

        const bond = await issueBond(issuer.target.toString(), token.target.toString(), bondConfig, deployer);

        await token.approve(bond.target, bondConfig.purchaseAmount * bondConfig.totalBonds);
        await token.transfer(bond.target, bondConfig.totalBonds * bondConfig.payoutAmount);
        await bond.settle()
        await bond.purchase(bondConfig.totalBonds, random.address);

        const vaultChanged = await deployVault(issuer.target);
        await issuer.changeVault(vaultChanged.target);


        await vaultChanged.updateBondFeeDetails(bond.target, BondFeeConstants.purchaseRate, BondFeeConstants.earlyRedemptionRate, BondFeeConstants.referrerRewardRate);
        await vaultOriginal.connect(random).claimReferralRewards(bond.target);
    })



})


