// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVault} from "./interfaces/IVault.sol";
import {Errors} from "./libraries/helpers/Errors.sol";
import {Bond} from "./Bond.sol";
import {Ownership} from "./libraries/helpers/Ownership.sol";

/// @title Issuer Contract
/// @notice Contract for issuing new Bond contracts, allowing management of bonds' lifecycle
/// @dev Inherits from Ownable for access control, implements IIssuer interface
/// @custom:security-contact hello@amet.finance, Twitter: @amet_finance
contract Issuer is Ownership {
    // Events declaration
    event BondIssued(address bondAddress);
    event VaultChanged(address previousVaultAddress, address newVaultAddress);
    event PauseChanged(bool isPaused);

    // State variables
    bool public isPaused;
    IVault public vault;

    /// @notice Constructor that sets the contract's owner
    constructor() Ownership(msg.sender) {}

    /// @notice Issues a new Bond contract
    /// @dev It is important to note that the Amet Finance protocol
    /// is not designed to support Fee On Transfer (FOT) tokens, rebasing tokens, or any tokens
    /// with mechanisms that alter balance logic. Using such tokens can result in unpredictable
    /// behavior and may cause the protocol to not function as intended. Users are strongly
    /// advised to utilize standard, non-rebasing tokens without fee-on-transfer features
    /// to ensure the integrity and expected operation of the bond issuance and lifecycle management.
    ///
    /// @dev Emits a BondIssued event upon successful issuance
    /// @param totalBonds The total number of bonds to issue
    /// @param maturityInBlocks The maturity period of the bond in blocks
    /// @param purchaseTokenAddress The address of the token used to purchase the bond
    /// @param purchaseAmount The amount of the purchase token required to buy the bond
    /// @param payoutTokenAddress The address of the token to be used for payouts
    /// @param payoutAmount The amount of the payout token to be paid out per bond
    function issue(uint40 totalBonds, uint40 maturityInBlocks, address purchaseTokenAddress, uint256 purchaseAmount, address payoutTokenAddress, uint256 payoutAmount) external payable {
        if (isPaused) Errors.revertOperation(Errors.Code.CONTRACT_PAUSED);

        Bond bond = new Bond(msg.sender, totalBonds, maturityInBlocks, purchaseTokenAddress, purchaseAmount, payoutTokenAddress, payoutAmount);

        address bondAddress = address(bond);
        vault.initializeBond{value: msg.value}(bondAddress);
        emit BondIssued(bondAddress);
    }

    /// @notice Changes the Vault contract address
    /// @dev Only callable by the owner, emits VaultChanged event
    /// @param vaultAddress The new vault address
    function changeVault(address vaultAddress) external onlyOwner {
        emit VaultChanged(address(vault), vaultAddress);
        vault = IVault(vaultAddress);
    }

    /// @notice Toggles the paused state of bond issuance
    /// @dev Only callable by the owner, emits PauseChanged event
    /// @param pausedState The new paused state
    function changePausedState(bool pausedState) external onlyOwner {
        isPaused = pausedState;
        emit PauseChanged(isPaused);
    }
}
