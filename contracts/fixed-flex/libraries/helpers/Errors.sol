// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Errors {
   
    enum Code {
        CONTRACT_PAUSED,
        FEE_INVALID,
        CONTRACT_NOT_INITIATED,
        CALLER_NOT_ISSUER_CONTRACT,
        ADDRESS_INVALID,
        ACTION_INVALID,
        ACTION_BLOCKED,
        INSUFFICIENT_PAYOUT,
        REDEEM_BEFORE_MATURITY
    }
    
    error OperationFailed(Code code);

    function revertOperation(Code code) internal pure {
        revert OperationFailed(code);
    }
}