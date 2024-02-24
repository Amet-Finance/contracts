import {ethers} from "hardhat";
import {BondFeeConstants} from "./constants";
import {AddressLike} from "ethers";
import {expect} from "chai";

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

export {
    deployIssuer,
    deployVault,
    revertOperation
}
