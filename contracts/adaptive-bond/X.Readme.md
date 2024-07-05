# Adaptive Bonds

## Introduction

Adaptive Bonds are designed to bring more flexibility and adaptability to market conditions. This innovative bond concept aims to enhance user experience (UX) by allowing issuers and investors to interact with bonds more dynamically. With customizable parameters and advanced features, Adaptive Bonds provide a more responsive and efficient approach to bond issuance and management.

## Overview of Major Changes

### Removal of Maturity Period

The traditional maturity period has been removed and replaced with two new parameters: **Cliff** and **Vesting**. This change allows for more granular control over when bondholders can start redeeming their bonds and over what period the redemption can occur.

### Referral Flow

The referral system has been revamped to include both on-chain and off-chain components. Referrals now require a code that must be claimed on the Amet Finance website. Verified referrers will gain a role on Discord. During bond purchases, the referral code must be applied, and rewards are sent directly to verified referrers, ensuring a streamlined and secure referral process.

### Guarantor Logic

Guarantors play a crucial role in ensuring bond repayment. They step in to provide the payout instead of the issuer, securing the bond's value. In return, guarantors receive fees for their service. When the issuer eventually deposits the payout, the guarantors' funds are returned to them, maintaining the integrity and security of the bond repayment process.

### Purchase and Payout Changes

Adaptive Bonds introduce several significant changes to the purchase and payout processes:

- **Customizable Purchase Price**: Issuers can adjust the bond purchase price after initial setup, providing flexibility to respond to market conditions.
- **Changeable Purchase Amount**: The purchase amount can be adjusted both upwards and downwards.
- **Increasable Payout Amount**: Issuers have the flexibility to increase the payout, offering better returns for investors.

### Start and End Blocks for Purchase

Issuers can now set specific start and end dates for bond purchases. This feature allows bonds to be available for purchase only within a specified date range, enhancing control over the bond sale period.

## Key Features

- **Bond Sale Details**: Customizable start and end dates for bond purchases.
- **Vesting Details**: Customizable cliffs and vesting periods, allowing only decreases.
- **Emergency Access Control**: Enhanced control for emergency scenarios.
- **Guarantor Logic**: Guarantors ensure repayment by providing the payout and receiving fees.
- **Referral and Guarantor Percentages**: Issuers can control the percentages allocated to referrals and guarantors.

### UI Enhancements

- **Integration with Gitcoin Passport** for issuer score.
- **Redemption Graphs**: Visual data on redemption.
- **Multisig Score**: Additional score for issuers using multisig.
- **Notifications**: Email and push notifications for bond-related information.
- **Fee Transparency**: Detailed breakdown of all fees associated with bond issuance, redemption, and trading.
- **Tutorials and Guides**: Comprehensive instructions for users on how to understand and use on-chain bonds and the platform.

### Contract Enhancements

- **Modularity**: Design contracts to be modular, allowing for easy upgrades and maintenance using proxy patterns (e.g., OpenZeppelin's upgradeable contracts).
- **Conditional Adjustments**: Automatically adjust bond terms, such as floating interest rates tied to a benchmark index.
- **Guarantor Advocacy**: Implement design where advocates secure the payout and receive a percentage from each purchase.
- **Role-Based Access Control (RBAC)**: Manage permissions for different users (e.g., admins, issuers, investors).
- **NFT Metadata**: Add attributes for issue date, maturity date, and interest rate.

## Considerations

1. **Remove Bond Quantity from Redeem**: Simplify the redemption process by eliminating the need to specify the number of bonds to redeem.
2. **Milestone Logic**: Avoid transferring all funds directly to the issuer, implementing milestone-based fund transfers instead.

# Guarantor Flow

Guarantors are essential for ensuring the repayment of bonds. They provide the payout instead of the issuer and receive fees in return. When the issuer deposits the payout, the guarantors' funds are returned to them. For example, if a purchase of $6000 occurs with 20% secured by guarantors, each guarantor receives a proportional fee based on their secured portion. The logic follows a FILO (First In, Last Out) order, ensuring fair distribution of fees.

# Referral Flow

Referrals require a code, which must be claimed on the Amet Finance website. Verified referrers gain a role on Discord. During a purchase, the referral code must be applied, and rewards are sent directly to verified referrers. This system ensures secure and efficient referral rewards distribution.
