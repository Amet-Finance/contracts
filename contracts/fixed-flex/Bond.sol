// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Types} from "./libraries/Types.sol";
import {IBond} from "./interfaces/IBond.sol";
import {IIssuer} from "./interfaces/IIssuer.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Errors} from "./libraries/helpers/Errors.sol";
import {Ownership} from "./libraries/helpers/Ownership.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Bond Contract
/// @notice ERC1155 token representing bonds with lifecycle management
/// @dev Inherits from ERC1155 for token functionality and Ownable for ownership management
/// @custom:security-contact hello@amet.finance, Twitter: @amet_finance
contract Bond is ERC1155, Ownership, ReentrancyGuard, IBond {
    using SafeERC20 for IERC20;

    // Event declarations
    event SettleContract();
    event DecreaseMaturityPeriod(uint40 maturityPeriodInBlocks);
    event UpdateBondSupply(uint40 totalBonds);
    event WithdrawExcessPayout(uint256 excessPayout);

    // State variable declarations
    uint16 private constant _PERCENTAGE_DECIMAL = 1000;
    IIssuer private immutable _issuerContract;
    Types.BondLifecycle public lifecycle;
    IERC20 public immutable purchaseToken;
    uint256 public immutable purchaseAmount;
    IERC20 public immutable payoutToken;
    uint256 public immutable payoutAmount;
    mapping(uint40 uniqueIndex => uint256 blockNumber) public purchaseBlocks;

    /// @notice Constructor to initialize the Bond contract
    /// @param issuer The address of the issuer
    /// @param initialTotalBonds Total number of bonds at issuance
    /// @param initialMaturityInBlocks Number of blocks until bond maturity
    /// @param initialPurchaseTokenAddress Address of the token used for purchasing bonds
    /// @param initialPurchaseAmount Amount of purchase token required per bond
    /// @param initialPayoutTokenAddress Address of the token used for bond payout
    /// @param initialPayoutAmount Amount of payout token distributed per bond
    constructor(
        address issuer,
        uint40 initialTotalBonds,
        uint40 initialMaturityInBlocks,
        address initialPurchaseTokenAddress,
        uint256 initialPurchaseAmount,
        address initialPayoutTokenAddress,
        uint256 initialPayoutAmount
    ) ERC1155("") Ownership(issuer) {
        _issuerContract = IIssuer(msg.sender);
        lifecycle = Types.BondLifecycle(initialTotalBonds, 0, 0, 0, initialMaturityInBlocks, false);
        purchaseToken = IERC20(initialPurchaseTokenAddress);
        purchaseAmount = initialPurchaseAmount;
        payoutToken = IERC20(initialPayoutTokenAddress);
        payoutAmount = initialPayoutAmount;
    }

    /// @notice Allows investors to purchase bonds
    /// @dev Transfers purchase amount to the vault and owner, and handles referral if applicable
    /// @param quantity The number of bonds to purchase
    /// @param referrer The address of the referrer, if any
    function purchase(uint40 quantity, address referrer) external nonReentrant {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;

        if (lifecycleTmp.purchased + quantity > lifecycleTmp.totalBonds) {
            Errors.revertOperation(Errors.Code.ACTION_INVALID);
        }

        IVault vault = _issuerContract.vault();
        uint8 purchaseRate = vault.getBondFeeDetails(address(this)).purchaseRate;

        uint256 totalAmount = quantity * purchaseAmount;
        uint256 purchaseFee = Math.mulDiv(totalAmount, purchaseRate, _PERCENTAGE_DECIMAL);

        purchaseToken.safeTransferFrom(msg.sender, address(vault), purchaseFee);
        purchaseToken.safeTransferFrom(msg.sender, owner(), totalAmount - purchaseFee);

        lifecycleTmp.purchased += quantity;
        purchaseBlocks[lifecycleTmp.uniqueBondIndex] = block.number;

        _mint(msg.sender, lifecycleTmp.uniqueBondIndex++, quantity, "");
        vault.recordReferralPurchase(msg.sender, referrer, quantity);
    }

    /// @notice Redeems specified bonds
    /// @dev Explain more about how redemption works, especially if isCapitulation has special logic
    /// @param bondIndexes An array of bond indexes to be redeemed
    /// @param quantity The number of bonds to redeem
    /// @param isCapitulation Indicates if the redemption is a capitulation (true) or regular redemption (false)
    function redeem(uint40[] calldata bondIndexes, uint40 quantity, bool isCapitulation) external nonReentrant {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;
        IERC20 payoutTokenTmp = payoutToken;

        uint8 earlyRedemptionRate = _issuerContract.vault().getBondFeeDetails(address(this)).earlyRedemptionRate;

        uint256 payoutAmountTmp = payoutAmount;
        uint256 totalPayout = quantity * payoutAmountTmp;

        lifecycleTmp.redeemed += quantity;

        if (totalPayout > payoutTokenTmp.balanceOf(address(this)) && !isCapitulation) {
            Errors.revertOperation(Errors.Code.INSUFFICIENT_PAYOUT);
        }

        uint256 bondIndexesLength = bondIndexes.length;

        for (uint40 i; i < bondIndexesLength; ) {
            uint40 bondIndex = bondIndexes[i];
            uint256 purchasedBlock = purchaseBlocks[bondIndex];
            bool isMature = purchasedBlock + lifecycleTmp.maturityPeriodInBlocks <= block.number;

            if (!isMature && !isCapitulation) Errors.revertOperation(Errors.Code.REDEEM_BEFORE_MATURITY);

            // Dubious typecast invalid as balance max is uint40
            uint40 balanceByIndex = uint40(balanceOf(msg.sender, bondIndex));
            uint40 burnCount = balanceByIndex >= quantity ? quantity : balanceByIndex;

            _burn(msg.sender, bondIndex, burnCount);
            quantity -= burnCount;

            if (isCapitulation && !isMature) {
                totalPayout -= _calculateCapitulationPayout(payoutAmountTmp, lifecycle.maturityPeriodInBlocks, burnCount, purchasedBlock, earlyRedemptionRate);
            }

            if (quantity == 0) break;
            unchecked {
                i += 1;
            }
        }

        if (quantity != 0) Errors.revertOperation(Errors.Code.ACTION_INVALID);

        payoutTokenTmp.safeTransfer(msg.sender, totalPayout);
    }

    /// @notice Calculates the payout reduction for a bond redeemed before maturity under capitulation conditions
    /// @dev This calculation takes into account the proportion of the maturity period elapsed and applies an early redemption fee
    /// @param payoutAmountTmp The amount to be paid out per bond
    /// @param maturityPeriodInBlocks The total maturity period of the bond in blocks
    /// @param burnCount The number of bonds being redeemed
    /// @param purchasedBlock The block number at which the bonds were purchased
    /// @param earlyRedemptionRate The early redemption fee rate, applied if the bond is redeemed before maturity
    /// @return payoutReduction The amount by which the total payout is reduced due to early redemption and fees
    function _calculateCapitulationPayout(uint256 payoutAmountTmp, uint40 maturityPeriodInBlocks, uint40 burnCount, uint256 purchasedBlock, uint8 earlyRedemptionRate) internal view returns (uint256 payoutReduction) {
        uint256 totalPayoutToBePaid = burnCount * payoutAmountTmp;
        uint256 bondsAmountForCapitulation = Math.mulDiv(totalPayoutToBePaid, block.number - purchasedBlock, maturityPeriodInBlocks);
        uint256 feeDeducted = bondsAmountForCapitulation - Math.mulDiv(bondsAmountForCapitulation, earlyRedemptionRate, _PERCENTAGE_DECIMAL);
        return (totalPayoutToBePaid - feeDeducted);
    }

    // ...

    /// @notice Marks the bond as settled
    /// @dev Once settled, certain actions such as issuing more bonds are not allowed
    /// @dev This function can only be called by the contract owner
    function settle() external onlyOwner {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;

        uint256 totalPayoutRequired = (lifecycleTmp.totalBonds - lifecycleTmp.redeemed) * payoutAmount;

        if (totalPayoutRequired > payoutToken.balanceOf(address(this))) {
            Errors.revertOperation(Errors.Code.INSUFFICIENT_PAYOUT);
        }

        lifecycleTmp.isSettled = true;
        emit SettleContract();
    }

    /// @notice Updates the total supply of bonds
    /// @dev Can only be called by the contract owner
    /// @dev Reverts if the new total is less than the number of purchased bonds or if bond is settled and the new total is more than the current total
    /// @param totalBonds The new total number of bonds to be set
    function updateBondSupply(uint40 totalBonds) external onlyOwner {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;

        if (lifecycleTmp.purchased > totalBonds || (lifecycleTmp.isSettled && totalBonds > lifecycleTmp.totalBonds)) {
            Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
        }

        lifecycleTmp.totalBonds = totalBonds;
        emit UpdateBondSupply(totalBonds);
    }

    /// @notice Withdraws excess payout tokens back to the owner
    /// @dev Can only be called by the contract owner
    /// @dev Reverts if there is no excess payout to withdraw
    function withdrawExcessPayout() external onlyOwner nonReentrant {
        Types.BondLifecycle memory lifecycleTmp = lifecycle;
        IERC20 payoutTokenTmp = payoutToken;

        // calculate for purchase but not redeemed bonds + potential purchases
        uint256 totalPayout = (lifecycleTmp.totalBonds - lifecycleTmp.redeemed) * payoutAmount;
        uint256 currentBalance = payoutTokenTmp.balanceOf(address(this));
        if (currentBalance <= totalPayout) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);

        uint256 excessPayout = currentBalance - totalPayout;
        payoutTokenTmp.safeTransfer(owner(), excessPayout);

        emit WithdrawExcessPayout(excessPayout);
    }

    /// @notice Decreases the maturity period of the bond
    /// @dev Can only be called by the contract owner
    /// @dev Emits a DecreaseMaturityPeriod event upon successful update
    /// @param maturityPeriodInBlocks The new maturity period in blocks
    /// @dev Reverts if the new maturity period is not less than the current one
    function decreaseMaturityPeriod(uint40 maturityPeriodInBlocks) external onlyOwner {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;
        if (maturityPeriodInBlocks >= lifecycleTmp.maturityPeriodInBlocks) {
            Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
        }

        lifecycleTmp.maturityPeriodInBlocks = maturityPeriodInBlocks;
        emit DecreaseMaturityPeriod(maturityPeriodInBlocks);
    }

    /// @notice Retrieves the purchase token and amount for the bond if it is fully settled
    /// @return purchaseToken The ERC20 token used for bond purchases if the bond is fully settled
    /// @return purchaseAmount The amount of the purchase token required to buy the bond if the bond is fully settled
    function getSettledPurchaseDetails() external view returns (IERC20, uint256) {
        Types.BondLifecycle memory lifecycleTmp = lifecycle;
        bool isSettledFully = lifecycleTmp.isSettled && lifecycleTmp.totalBonds == lifecycleTmp.purchased;
        if (!isSettledFully) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);

        return (purchaseToken, purchaseAmount);
    }

    /// @notice Gets the URI for the ERC1155 tokens
    /// @dev Overrides the ERC1155 uri method to concatenate the base URI, contract address, and a fixed file extension for gas efficiency
    /// @param /* id */ The token ID (unused in this override)
    /// @return The constructed token URI
    function uri(uint256 /* id */) public view override returns (string memory) {
        return string(abi.encodePacked(Types.BASE_URI, Strings.toHexString(uint160(address(this)), 20), "_80001.json"));
    }
}
