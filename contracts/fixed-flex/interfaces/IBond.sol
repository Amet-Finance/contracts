// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IBond {
    function getSettledPurchaseDetails() external view returns (IERC20, uint256);
}
