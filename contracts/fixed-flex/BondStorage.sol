// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Types} from "./libraries/Types.sol";

contract BondStorage {
    mapping(address => uint256) internal _principals;
    mapping(address => mapping(address => uint256)) internal _approvals;
    mapping(uint256 purchaseIndex => mapping(address account => uint256)) internal _balanceByPurchase;
    mapping(uint256 purchaseIndex => mapping(address account => uint256)) internal _redeemBalance;

    Types.Bond bonds;
}