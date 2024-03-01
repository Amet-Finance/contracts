// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Types {
    string private constant BASE_URI = "https://storage.amet.finance/contracts/";

    struct BondLifecycle {
        uint40 totalBonds; // Total number of bonds issued
        uint40 purchased; // Number of bonds purchased
        uint40 redeemed; // Number of bonds redeemed
        uint40 uniqueBondIndex; // Unique identifier for the bond
        uint40 maturityPeriodInBlocks; // Maturity period of the bond in blocks
        bool isSettled; // Indicates if the bond is settled (no further actions allowed)
    }

    struct BondFeeDetails {
        uint8 purchaseRate; // Fee rate for bond purchases
        uint8 earlyRedemptionRate; // Fee rate for early bond redemption
        uint8 referrerRewardRate; // Reward rate for referrers
        bool isInitiated; // Tells if the bond was created or not
    }

    struct ReferrerRecord {
        uint40 quantity;
        bool isRepaid;
    }
}
