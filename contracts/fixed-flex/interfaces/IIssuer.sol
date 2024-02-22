// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVault} from "./IVault.sol";

/// @title IIssuer Interface
/// @notice Interface for the Issuer contract
interface IIssuer {
    
    /// @notice Getter for the vault associated with the issuer
    /// @return The IVault instance associated with the issuer
    function vault() external returns (IVault);
}
