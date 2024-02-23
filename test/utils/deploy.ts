import {ethers} from "hardhat";
import {BondFeeConstants} from "./constants";
import {AddressLike} from "ethers";

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

export {
    deployIssuer,
    deployVault
}
