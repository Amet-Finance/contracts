// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Errors} from "./Errors.sol";

library Validator {
    function validateAddress(address addr) internal pure {
        if (addr == address(0)) Errors.revertOperation(Errors.Code.ADDRESS_INVALID);
    }
}
