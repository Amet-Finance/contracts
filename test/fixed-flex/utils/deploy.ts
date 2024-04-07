import {ethers} from "hardhat";
import {BondFeeConstants} from "./constants";
import {AddressLike} from "ethers";
import {expect} from "chai";
import {Bond__factory, CustomToken__factory, Issuer__factory} from "../../../typechain-types";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {Bond} from "./types";

function deployIssuer(signer?: HardhatEthersSigner) {
    return ethers.deployContract("Issuer", [], signer)
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

function deployToken(signer?: HardhatEthersSigner) {
    return ethers.deployContract("CustomToken", [], signer)
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

async function issueBond(issuerAddress: string, bond: Bond, deployer: HardhatEthersSigner) {
    const issuer = Issuer__factory.connect(issuerAddress, deployer);
    const bondTransaction = await issuer.issue(
        bond,
        {value: BondFeeConstants.initialIssuanceFee}
    );
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
    deployToken,
    revertOperation,
    issueBond
}