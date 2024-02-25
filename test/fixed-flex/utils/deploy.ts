import {ethers} from "hardhat";
import {BondFeeConstants} from "./constants";
import {AddressLike} from "ethers";
import {expect} from "chai";
import {Bond__factory, CustomToken__factory, Issuer__factory} from "../../../typechain-types";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {BondConfig} from "./types";

function deployIssuer() {
    return ethers.deployContract("Issuer", [])
}

function deployVault(
    initialIssuerAddress: AddressLike,
    initialIssuanceFee = BondFeeConstants.initialIssuanceFee,
    purchaseRate = BondFeeConstants.purchaseRate,
    earlyRedemptionRate = BondFeeConstants.earlyRedemptionRate,
    referrerRewardRate = BondFeeConstants.referrerRewardRate
) {
    return ethers.deployContract("Vault", [
        initialIssuerAddress,
        initialIssuanceFee,
        purchaseRate,
        earlyRedemptionRate,
        referrerRewardRate
    ])
}

async function revertOperation(bond: any, fn: Promise<any>, customError?: string, code?: any) {
    const test = expect(fn).to.be;
    if (customError) {
        if (code) {
            await test.revertedWithCustomError(bond, customError).withArgs(code);
        } else {
            await test.revertedWithCustomError(bond, customError)
        }
    } else {
        await test.reverted;
    }
}



async function issueBond(issuerAddress: string, tokenAddress: string, bondConfig: BondConfig, deployer: HardhatEthersSigner) {
    const issuer = Issuer__factory.connect(issuerAddress, deployer);
    const token = CustomToken__factory.connect(tokenAddress);
    const bondTransaction = await issuer.issue(
        bondConfig.totalBonds,
        bondConfig.maturityPeriodInBlocks,
        token.target,
        bondConfig.purchaseAmount,
        token.target,
        bondConfig.payoutAmount, {value: BondFeeConstants.initialIssuanceFee});
    const txRecipient = await ethers.provider.getTransactionReceipt(bondTransaction.hash);
    if (!txRecipient?.logs) throw Error("Failed to deploy")

    for (const log of txRecipient.logs) {
        const decodedData = issuer.interface.parseLog({
            topics: [...log.topics],
            data: log.data
        });
        if (decodedData?.name === "BondIssued") {
            return Bond__factory.connect(decodedData.args.bondAddress, deployer)
        }
    }

    throw Error("Failed to issue bond")
}
export {
    deployIssuer,
    deployVault,
    revertOperation,
    issueBond
}
