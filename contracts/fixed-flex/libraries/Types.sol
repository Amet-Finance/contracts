// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Types {
    uint16 internal constant _PERCENTAGE_DECIMAL = 1000;
    string internal constant _BASE_URI = "https://storage.amet.finance/contracts/";

    struct Bond {
        string isin;
        string name;
        string symbol;
        address currency;
        uint256 denomination;
        uint256 issueVolume;
        uint256 couponRate;
        uint256 issueDate;     // issue date in blocks
        uint256 maturityDate;  // maturity date in blocks
        uint256 issuePrice;
        address payoutCurrency;
        uint256 payoutAmount;
    }
    
    struct BondLifecycle {
        uint40 purchased; // Number of bonds purchased
        uint40 redeemed; // Number of bonds redeemed
        uint40 uniqueBondIndex; // Unique identifier for the bond
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
        uint40 claimed;
    }
}