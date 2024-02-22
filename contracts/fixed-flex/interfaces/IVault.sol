// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Types} from "../libraries/Types.sol";

interface IVault {
    function initializeBond(address bondAddress) external payable;
    function getBondFeeDetails(address bondAddress) external returns (Types.BondFeeDetails calldata);
    function recordReferralPurchase(address operator, address referrer, uint40 quantity) external;
}
