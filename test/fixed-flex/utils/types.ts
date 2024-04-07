type Bond = {
    isin: string,
    name: string,
    symbol: string,
    currency: string,
    denomination: bigint,
    issueVolume: bigint,
    couponRate: bigint,
    issueDate: bigint,
    maturityDate: bigint,
    issuePrice: bigint,
    payoutCurrency: string,
    payoutAmount: bigint
}

type BondConfig = {
    totalBonds: bigint,
    maturityPeriodInBlocks: bigint,
    purchaseAmount: bigint,
    payoutAmount: bigint
}

export type {
    Bond,
    BondConfig
}