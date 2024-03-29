// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title IBond Interface
/// @notice Interface for the Bond contract managing the financial aspects of bonds
interface IBond {
    /// @notice Retrieves the purchase token and amount details for the bond
    /// @return purchaseToken The ERC20 token used for bond purchases
    /// @return purchaseAmount The amount of the purchase token required to buy the bond
    function getPurchaseDetails() external view returns (IERC20 purchaseToken, uint256 purchaseAmount);
}
