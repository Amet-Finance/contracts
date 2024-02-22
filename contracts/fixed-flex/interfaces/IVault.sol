// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Types } from "../libraries/Types.sol";

/// @title IVault Interface
/// @notice Interface for the Vault contract managing bonds
interface IVault {
    
    /// @notice Initializes a bond with default fee settings
    /// @dev This function should be callable only by the issuer contract
    /// @param bondAddress The address of the bond to initialize
    function initializeBond(address bondAddress) external payable;

    /// @notice Retrieves the fee details for a specific bond
    /// @param bondAddress The address of the bond
    /// @return Bond fee details including purchase, early redemption, and referral reward rates
    function getBondFeeDetails(address bondAddress) external returns (Types.BondFeeDetails calldata);

    /// @notice Records a referral purchase for a bond
    /// @param operator The address of the operator performing the purchase
    /// @param referrer The address of the referrer
    /// @param quantity The quantity of bonds purchased
    function recordReferralPurchase(address operator, address referrer, uint40 quantity) external;
}
