const BondFeeConstants = {
    initialIssuanceFee: BigInt(1e17),
    purchaseRate: BigInt(50),
    earlyRedemptionRate: BigInt(25),
    referrerRewardRate: BigInt(12)
}

const OperationFailed = "OperationFailed"
const OwnableUnauthorizedAccount ="OwnableUnauthorizedAccount"
const ERC20InsufficientBalance = "ERC20InsufficientBalance";
const OperationCodes = {
    CONTRACT_PAUSED: 0,
    FEE_INVALID: 1,
    CONTRACT_NOT_INITIATED: 2,
    CALLER_NOT_ISSUER_CONTRACT: 3,
    ACTION_INVALID: 4,
    ACTION_BLOCKED: 5,
    INSUFFICIENT_PAYOUT: 6,
    REDEEM_BEFORE_MATURITY: 7
}
export {
    BondFeeConstants,
    OperationFailed,
    OwnableUnauthorizedAccount,
    OperationCodes,
    ERC20InsufficientBalance
}
