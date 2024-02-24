// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Errors} from "./Errors.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Ownership Contract
/// @notice Provides ownership management with a disabled renounce ownership feature
/// @dev Extends OpenZeppelin's Ownable contract with modified renounceOwnership functionality
contract Ownership is Ownable {
    /// @notice Initializes the contract setting the provided address as the initial owner
    /// @param owner The address to be set as the initial owner of the contract
    constructor(address owner) Ownable(owner) {}

    /// @notice Prevents renouncing ownership of the contract
    /// @dev Overrides the renounceOwnership function from OpenZeppelin's Ownable to permanently disable owner renunciation
    /// @dev Reverts with ACTION_BLOCKED error code indicating the operation is intentionally blocked for security reasons
    function renounceOwnership() public view override onlyOwner {
        Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
    }
}
