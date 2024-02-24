// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVault} from "./interfaces/IVault.sol";
import {IBond} from "./interfaces/IBond.sol";
import {Errors} from "./libraries/helpers/Errors.sol";
import {Types} from "./libraries/Types.sol";
import {Validator} from "./libraries/helpers/Validator.sol";
import {Ownership} from "./libraries/helpers/Ownership.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Vault Contract
/// @notice Manages financial aspects of bonds including fees and referral rewards
contract Vault is Ownership, ReentrancyGuard, IVault {
    using SafeERC20 for IERC20;

    // Events declaration
    event RestrictionStatusUpdated(address referrer, bool isBlocked);
    event IssuanceFeeChanged(uint256 fee);
    event InitialFeeDetailsUpdated(uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate);
    event FeesWithdrawn(address token, address to, uint256 amount);
    event ReferralRecord(address referrer, address bondAddress, uint40 quantity);
    event ReferrerRewardClaimed(address referrer, address bondAddress, uint256 amount);
    event BondFeeDetailsUpdated(address bondAddress, uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate);

    uint16 constant PERCENTAGE_DECIMAL = 1000;
    uint256 public issuanceFee;
    address public immutable issuerAddress;
    Types.BondFeeDetails public initialBondFeeDetails;

    mapping(address => bool) private _restrictedAddresses;
    mapping(address => Types.BondFeeDetails) private _bondFeeDetails;
    mapping(address => mapping(address => Types.ReferrerRecord)) private _referrers;

    /// @notice Constructs the Vault contract
    /// @param initialIssuerAddress The address of the bond issuer
    /// @param initialIssuanceFee The initial fee for bond issuance
    /// @param purchaseRate The rate for bond purchases
    /// @param earlyRedemptionRate The rate for early bond redemptions
    /// @param referrerRewardRate The reward rate for referrers
    constructor(address initialIssuerAddress, uint256 initialIssuanceFee, uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate) Ownership(msg.sender) {
        Validator.validateAddress(initialIssuerAddress);
        _validateBondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate);

        issuerAddress = initialIssuerAddress;
        issuanceFee = initialIssuanceFee;
        initialBondFeeDetails = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
    }

    /// @notice Receive function to handle direct ether transfers to the contract
    receive() external payable {}

    /// @notice Initializes a bond with the default fee settings
    /// @param bondAddress The address of the bond to initialize
    function initializeBond(address bondAddress) external payable {
        if (msg.sender != issuerAddress) Errors.revertOperation(Errors.Code.CALLER_NOT_ISSUER_CONTRACT);
        if (msg.value != issuanceFee) Errors.revertOperation(Errors.Code.FEE_INVALID);
        _bondFeeDetails[bondAddress] = initialBondFeeDetails;
    }

    /// @notice Records a referral purchase for a bond, only if conditions are met
    /// @param operator The address of the operator performing the purchase
    /// @param referrer The address of the referrer
    /// @param quantity The quantity of bonds purchased
    function recordReferralPurchase(address operator, address referrer, uint40 quantity) external {
        _isBondInitiated(_bondFeeDetails[msg.sender]);
        if (referrer != address(0) && referrer != operator) {
            _referrers[msg.sender][referrer].quantity += quantity;
            emit ReferralRecord(referrer, msg.sender, quantity);
        }
    }

    /// @notice Claims referral rewards for a specified bond
    /// @param bondAddress The address of the bond for which to claim rewards
    function claimReferralRewards(address bondAddress) external nonReentrant {
        _isAddressUnrestricted(msg.sender);
        Types.ReferrerRecord storage referrer = _referrers[bondAddress][msg.sender];
        Types.BondFeeDetails memory bondFeeDetails = _bondFeeDetails[bondAddress];
        IBond bond = IBond(bondAddress);

        _isBondInitiated(bondFeeDetails);

        if (referrer.isRepaid || referrer.quantity == 0) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);

        (IERC20 purchaseToken, uint256 purchaseAmount) = bond.getSettledPurchaseDetails();
        referrer.isRepaid = true;
        uint256 rewardAmount = Math.mulDiv((referrer.quantity * purchaseAmount), bondFeeDetails.referrerRewardRate, PERCENTAGE_DECIMAL);
        purchaseToken.safeTransfer(msg.sender, rewardAmount);
        emit ReferrerRewardClaimed(msg.sender, bondAddress, rewardAmount);
    }

    /// @notice Updates the initial fee settings for new bonds
    /// @param purchaseRate The rate for bond purchases
    /// @param earlyRedemptionRate The rate for early bond redemptions
    /// @param referrerRewardRate The reward rate for referrers
    /// @dev Emits a InitialFeeDetailsUpdated event upon successful update
    function updateInitialFees(uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate) external onlyOwner {
        initialBondFeeDetails = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
        emit InitialFeeDetailsUpdated(purchaseRate, earlyRedemptionRate, referrerRewardRate);
    }

    /// @notice Updates the issuance fee for bonds
    /// @param newIssuanceFee The new fee amount for issuing bonds
    /// @dev Emits a IssuanceFeeChanged event
    function updateIssuanceFee(uint256 newIssuanceFee) external onlyOwner {
        issuanceFee = newIssuanceFee;
        emit IssuanceFeeChanged(newIssuanceFee);
    }

    /// @notice Updates the fee details for a specific bond
    /// @dev Can only be called by the contract owner
    /// @param bondAddress The address of the bond to update fee details for
    /// @param purchaseRate The new purchase rate to be set
    /// @param earlyRedemptionRate The new early redemption rate to be set
    /// @param referrerRewardRate The new referrer reward rate to be set
    function updateBondFeeDetails(address bondAddress, uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate) external onlyOwner {
        Types.BondFeeDetails storage bondFeeDetails = _bondFeeDetails[bondAddress];
        _isBondInitiated(bondFeeDetails);

        bondFeeDetails.purchaseRate = purchaseRate;
        bondFeeDetails.earlyRedemptionRate = earlyRedemptionRate;
        bondFeeDetails.referrerRewardRate = referrerRewardRate;

        emit BondFeeDetailsUpdated(bondAddress, purchaseRate, earlyRedemptionRate, referrerRewardRate);
    }

    /// @notice Blocks or unblocks an address for referral rewards
    /// @param referrer The address of the referrer to be blocked or unblocked
    /// @param status True to block the address, false to unblock
    function updateRestrictionStatus(address referrer, bool status) external onlyOwner {
        Validator.validateAddress(referrer);
        _restrictedAddresses[referrer] = status;
        emit RestrictionStatusUpdated(referrer, status);
    }

    /// @notice Withdraws either Ether or ERC20 tokens to a specified address
    /// @dev Allows withdrawal of Ether if the token address is zero, otherwise withdraws ERC20 tokens
    /// @param token The ERC20 token contract address or zero address for Ether
    /// @param toAddress The address to which the funds will be transferred
    /// @param amount The amount of funds to transfer
    /// @dev Emits a FeesWithdrawn event upon successful withdrawal
    function withdraw(address token, address toAddress, uint256 amount) external onlyOwner {
        Validator.validateAddress(toAddress);

        if (token == address(0)) {
            (bool success, ) = toAddress.call{value: amount}("");
            if (!success) Errors.revertOperation(Errors.Code.ACTION_INVALID);
        } else {
            IERC20(token).safeTransfer(toAddress, amount);
        }

        emit FeesWithdrawn(token, toAddress, amount);
    }

    /// @notice Retrieves the fee details for a specific bond
    /// @param bondAddress The address of the bond
    /// @return The fee details of the specified bond
    function getBondFeeDetails(address bondAddress) external view returns (Types.BondFeeDetails memory) {
        return _bondFeeDetails[bondAddress];
    }

    /// @notice Checks if the referrer is restricted
    /// @param referrer The address of the referrer to validate
    function _isAddressUnrestricted(address referrer) private view {
        if (_restrictedAddresses[referrer]) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
    }

    /// @notice Checks if the bond is intiated
    /// @param bond The address of the bond
    function _isBondInitiated(Types.BondFeeDetails memory bond) private pure {
        if (!bond.isInitiated) Errors.revertOperation(Errors.Code.CONTRACT_NOT_INITIATED);
    }

    /// @notice Validates the bond fee details before updating them
    /// @param purchaseRate The purchase rate to be validated
    /// @param earlyRedemptionRate The early redemption rate to be validated
    /// @param referrerRewardRate The referrer reward rate to be validated
    /// @dev This function could be expanded with more complex validation logic as needed
    function _validateBondFeeDetails(uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate) private pure {
        // Range from 0 - 1000: 50 for 5%
        if (purchaseRate >= PERCENTAGE_DECIMAL) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
        if (earlyRedemptionRate >= PERCENTAGE_DECIMAL) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
        if (referrerRewardRate >= PERCENTAGE_DECIMAL || referrerRewardRate > purchaseRate) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
    }
}
