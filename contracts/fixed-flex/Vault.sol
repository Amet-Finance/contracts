// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVault} from "./interfaces/IVault.sol";
import {IBond} from "./interfaces/IBond.sol";
import {Errors} from "./libraries/helpers/Errors.sol";
import {Types} from "./libraries/Types.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault Contract
/// @notice Manages financial aspects of bonds including fees and referral rewards
contract Vault is Ownable, IVault {
    using SafeERC20 for IERC20;

    /// @notice Different types of fees applicable to bonds
    enum FeeTypes {
        IssuanceFee,
        ReferralPurchase
    }

    /// @notice Emitted when a referrer's status is blocked or unblocked for referral rewards
    event BlockAddressForReferralRewards(address indexed referrer, bool isBlocked);

    /// @notice Emitted when a fee type is changed
    event FeeChanged(FeeTypes feeType, uint256 newFee);

    /// @notice Emitted when fees are withdrawn
    event FeesWithdrawn(address to, uint256 amount, bool isERC20);

    /// @notice Emitted when a referral is recorded
    event ReferralRecord(address referrer, address bondAddress, uint40 quantity);

    /// @notice Emitted when a referrer claims their reward
    event ReferrerRewardClaimed(address referrer, address bondAddress, uint256 amount);

    uint256 public issuanceFee;
    address public immutable issuerAddress;
    Types.BondFeeDetails public initialBondFeeDetails;

    mapping(address => bool) private _blacklistAddresses;
    mapping(address => Types.BondFeeDetails) private _bondFeeDetails;
    mapping(address => mapping(address => Types.ReferrerRecord)) private _referrers;

    /// @notice Ensures the function is called by the issuer contract
    modifier onlyIssuerContract() {
        require(msg.sender == issuerAddress, "Caller is not the issuer contract");
        _;
    }

    /// @notice Checks if the referrer is blacklisted
    /// @param referrer The address of the referrer to validate
    modifier validateReferrer(address referrer) {
        require(!_blacklistAddresses[referrer], "Referrer is blacklisted");
        _;
    }

    /// @notice Receive function to handle direct ether transfers to the contract
    receive() external payable {}

    /// @notice Constructs the Vault contract
    /// @param initialIssuerAddress The address of the bond issuer
    /// @param initialIssuanceFee The initial fee for bond issuance
    /// @param purchaseRate The rate for bond purchases
    /// @param earlyRedemptionRate The rate for early bond redemptions
    /// @param referrerRewardRate The reward rate for referrers
    constructor(
        address initialIssuerAddress,
        uint256 initialIssuanceFee,
        uint8 purchaseRate,
        uint8 earlyRedemptionRate,
        uint8 referrerRewardRate
    ) Ownable(msg.sender) {
        require(initialIssuerAddress != address(0), "Issuer address cannot be zero");
        issuerAddress = initialIssuerAddress;
        issuanceFee = initialIssuanceFee;
        initialBondFeeDetails = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
    }

    /// @notice Initializes a bond with the default fee settings
    /// @param bondAddress The address of the bond to initialize
    function initializeBond(address bondAddress) external payable onlyIssuerContract {
        require(msg.value == issuanceFee, "Incorrect fee amount");
        _bondFeeDetails[bondAddress] = initialBondFeeDetails;
    }

    /// @notice Records a referral purchase for a bond
    /// @param operator The address of the operator performing the purchase
    /// @param referrer The address of the referrer
    /// @param quantity The quantity of bonds purchased
    function recordReferralPurchase(address operator, address referrer, uint40 quantity) external {
        require(_bondFeeDetails[msg.sender].isInitiated, "Bond contract not initiated");
        require(referrer != address(0) && referrer != operator, "Invalid referrer address");

        _referrers[msg.sender][referrer].quantity += quantity;
        emit ReferralRecord(referrer, msg.sender, quantity);
    }

    /// @notice Claims referral rewards for a specified bond
    /// @param bondAddress The address of the bond for which to claim rewards
    function claimReferralRewards(address bondAddress) external validateReferrer(msg.sender) {
        Types.ReferrerRecord storage referrer = _referrers[bondAddress][msg.sender];
        Types.BondFeeDetails memory bondFeeDetails = _bondFeeDetails[bondAddress];
        IBond bond = IBond(bondAddress);

        require(!(referrer.isRepaid || referrer.quantity == 0), "Referral rewards already claimed or no referrals");

        (IERC20 purchaseToken, uint256 purchaseAmount) = bond.getSettledPurchaseDetails();
        referrer.isRepaid = true;
        uint256 rewardAmount = (referrer.quantity * purchaseAmount * bondFeeDetails.referrerRewardRate) / 1000;
        purchaseToken.safeTransfer(msg.sender, rewardAmount);
        emit ReferrerRewardClaimed(msg.sender, bondAddress, rewardAmount);
    }

    /// @notice Updates the initial fee settings for new bonds
    /// @param purchaseRate The rate for bond purchases
    /// @param earlyRedemptionRate The rate for early bond redemptions
    /// @param referrerRewardRate The reward rate for referrers
    function updateInitialFees(uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate)
        external
        onlyOwner
    {
        initialBondFeeDetails = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
    }

    /// @notice Updates the issuance fee for bonds
    /// @param newIssuanceFee The new fee amount for issuing bonds
    function updateIssuanceFee(uint256 newIssuanceFee) external onlyOwner {
        issuanceFee = newIssuanceFee;
    }

    /// @notice Blocks or unblocks an address for referral rewards
    /// @param referrer The address of the referrer to be blocked or unblocked
    /// @param status True to block the address, false to unblock
    function blockAddressForReferralRewards(address referrer, bool status) external onlyOwner {
        require(referrer != address(0), "Referrer address cannot be zero");
        _blacklistAddresses[referrer] = status;
        emit BlockAddressForReferralRewards(referrer, status);
    }

    /// @notice Withdraws Ether (issuance fees) to a specified address
    /// @param toAddress The address to which the Ether will be transferred
    /// @param amount The amount of Ether to transfer
    function withdrawETH(address toAddress, uint256 amount) external onlyOwner {
        require(toAddress != address(0), "Withdrawal address cannot be zero");
        (bool success,) = toAddress.call{value: amount}("");
        require(success, "Ether transfer failed");
        emit FeesWithdrawn(toAddress, amount, false);
    }

    /// @notice Withdraws ERC20 tokens (purchase fees) to a specified address
    /// @param token The ERC20 token contract address
    /// @param toAddress The address to which the tokens will be transferred
    /// @param amount The amount of tokens to transfer
    function withdrawERC20(address token, address toAddress, uint256 amount) external onlyOwner {
        require(token != address(0), "Token address cannot be zero");
        require(toAddress != address(0), "Withdrawal address cannot be zero");
        IERC20(token).safeTransfer(toAddress, amount);
        emit FeesWithdrawn(toAddress, amount, true);
    }

    /// @notice Retrieves the fee details for a specific bond
    /// @param bondAddress The address of the bond
    /// @return The fee details of the specified bond
    function getBondFeeDetails(address bondAddress) external view returns (Types.BondFeeDetails memory) {
        return _bondFeeDetails[bondAddress];
    }
}
