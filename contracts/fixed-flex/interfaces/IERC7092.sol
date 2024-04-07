// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
* @title ERC-7092 Financial Bonds Standard
*/
interface IERC7092 /** is ERC165 */ {
    // events
    /**
    * @notice MUST be emitted when bond tokens are transferred, issued or redeemed, except during contract creation
    * @param _from the account that owns bonds
    * @param _to the account that receives the bond
    * @param _amount amount of bond tokens to be transferred
    */
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

    /**
    * @notice MUST be emitted when an account is approved or when the allowance is decreased
    * @param _owner bond token's owner
    * @param _spender the account to be allowed to spend bonds
    * @param _amount amount of bond tokens allowed by _owner to be spent by `_spender`
    *        Or amount of bond tokens to decrease allowance from `_spender`
    */
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);

    /**
    * @notice MUST be emitted when multiple bond tokens are transferred, issued or redeemed, with the exception being during contract creation
    * @param _from array of bondholders accounts
    * @param _to array of accounts to transfer bonds to
    * @param _amount array of amounts of bond tokens to be transferred
    *
    ** OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present. MUST be emitted in `batchTransfer` and `batchTransferFrom` functions
    */
    event TransferBatch(address[] _from, address[] _to, uint256[] _amount);

    /**
    * @notice MUST be emitted when multiple accounts are approved or when the allowance is decreased from multiple accounts
    * @param _owner bondholder account
    * @param _spender array of accounts to be allowed to spend bonds, or to decrase the allowance from
    * @param _amount array of amounts of bond tokens allowed by `_owner` to be spent by multiple accounts in `_spender`.
    *
    ** OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present. MUST be emitted in `batchApprove` and `batchDecreaseAllowance` functions
    */
    event ApprovalBatch(address indexed _owner, address[] _spender, uint256[] _amount);

    // getter functions
    /**
    *  @notice Returns the bond isin
    */
    function isin() external view returns(string memory);

    /**
    * @notice Returns the bond name
    */
    function name() external view returns(string memory);

    /**
    * @notice Returns the bond symbol
    *         It is RECOMMENDED to represent the symbol as a combination of the issuer Issuer'shorter name and the maturity date
    *         Ex: If a company named Green Energy issues bonds that will mature on october 25, 2030, the bond symbol could be `GE30` or `GE2030` or `GE102530`
    */
    function symbol() external view returns(string memory);

    /**
    * @notice Returns the bond currency. This is the contract address of the token used to pay and return the bond principal
    */
    function currency() external view returns(address);

    /**
    * @notice Returns the bond denominiation. This is the minimum amount in which the Bonds may be issued. It must be expressend in unit of the principal currency
    *         ex: If the denomination is equal to 1,000 and the currency is USDC, then the bond denomination is equal to 1,000 USDC
    */
    function denomination() external view returns(uint256);

    /**
    * @notice Returns the issue volume (total debt amount). It is RECOMMENDED to express the issue volume in denomination unit.
    */
    function issueVolume() external view returns(uint256);

    /**
    * @notice Returns the bond interest rate. It is RECOMMENDED to express the interest rate in basis point unit.
    *         1 basis point = 0.01% = 0.0001
    *         ex: if interest rate = 5%, then coupon() => 500 basis points
    */
    function couponRate() external view returns(uint256);

    /**
    * @notice Returns the date when bonds were issued to investors. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function issueDate() external view returns(uint256);

    /**
    * @notice Returns the bond maturity date, i.e, the date when the pricipal is repaid. This is a Unix Timestamp like the one returned by block.timestamp
    *         The maturity date MUST be greater than the issue date
    */
    function maturityDate() external view returns(uint256);

    /**
    * @notice Returns the principal of an account. It is RECOMMENDED to express the principal in the bond currency unit (USDC, DAI, etc...)
    * @param _account account address
    */
    function principalOf(address _account) external view returns(uint256);

    /**
    * @notice Returns the amount of tokens the `_spender` account has been authorized by the `_owner``
    *         acount to manage their bonds
    * @param _owner the bondholder address
    * @param _spender the address that has been authorized by the bondholder
    */
    function allowance(address _owner, address _spender) external view returns(uint256);

    // setter functions
    /**
    * @notice Authorizes `_spender` account to manage `_amount`of their bond tokens
    * @param _spender the address to be authorized by the bondholder
    * @param _amount amount of bond tokens to approve
    */
    function approve(address _spender, uint256 _amount) external returns(bool);

    /**
    * @notice Lowers the allowance of `_spender` by `_amount`
    * @param _spender the address to be authorized by the bondholder
    * @param _amount amount of bond tokens to remove from allowance
    */
    function decreaseAllowance(address _spender, uint256 _amount) external returns(bool);

    /**
    * @notice Moves `_amount` bonds to address `_to`. This methods also allows to attach data to the token that is being transferred
    * @param _to the address to send the bonds to
    * @param _amount amount of bond tokens to transfer
    * @param _data additional information provided by the token holder
    */
    function transfer(address _to, uint256 _amount, bytes calldata _data) external returns(bool);

    /**
    * @notice Moves `_amount` bonds from an account that has authorized the caller through the approve function
    *         This methods also allows to attach data to the token that is being transferred
    * @param _from the bondholder address
    * @param _to the address to transfer bonds to
    * @param _amount amount of bond tokens to transfer.
    * @param _data additional information provided by the token holder
    */
    function transferFrom(address _from, address _to, uint256 _amount, bytes calldata _data) external returns(bool);

    // batch functions
    /**
    * @notice Authorizes multiple spender accounts to manage a specified `_amount` of the bondholder tokens
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to approve
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect these values to be present. The method is used to improve usability.
    */
    function batchApprove(address[] calldata _spender, uint256[] calldata _amount) external returns(bool);

    /**
    * @notice Decreases the allowance of multiple spenders by corresponding amounts in `_amount`
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to decrease the allowance from
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present. The method is used to decrease token allowance.
    */
    function batchDecreaseAllowance(address[] calldata _spender, uint256[] calldata _amount) external returns(bool);

    /**
    * @notice Transfers multiple bonds with amounts specified in the array `_amount` to the corresponding accounts in the array `_to`, with the option to attach additional data
    * @param _to array of accounts to send the bonds to
    * @param _amount array of amounts of bond tokens to transfer
    * @param _data array of additional information provided by the token holder
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present.
    */
    function batchTransfer(address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data) external returns(bool);

    /**
    * @notice Transfers multiple bonds with amounts specified in the array `_amount` to the corresponding accounts in the array `_to` from an account that have been authorized by the `_from` account
    *         This method also allows to attach data to tokens that are being transferred
    * @param _from array of bondholder accounts
    * @param _to array of accounts to transfer bond tokens to
    * @param _amount array of amounts of bond tokens to transfer.
    * @param _data array of additional information provided by the token holder
    *
    ** OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present.
    */
    function batchTransferFrom(address[] calldata _from, address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data) external returns(bool);
}

/**
* @notice Cross-chain Interface
*         This interface defines functions that allow to manage bonds accross several chains
*/
interface IERC7092CrossChain /** is ERC165 */ {
    // events
    /**
    * @notice MUST be emitted when bond tokens are transferred or redeemed in a cross-chain transaction
    * @param _from bondholder account
    * @param _to account the transfer bond tokens to
    * @param _amount amount of bond tokens to be transferred
    * @param _destinationChainID The unique ID that identifies the destination Chain
    */
    event CrossChainTransfer(address indexed _from, address indexed _to, uint256 _amount, bytes32 _destinationChainID);

    /**
    * @notice MUST be emitted when several bond tokens are transferred or redeemed in a cross-chain transaction
    * @param _from array of bondholders accounts
    * @param _to array of accounts that receive the bond
    * @param _amount array of amount of bond tokens to be transferred
    * @param _destinationChainID array of unique IDs that identify the destination Chain
    */
    event CrossChainTransferBatch(address[] _from, address[] _to, uint256[] _amount, bytes32[] _destinationChainID);

    /**
    * @notice MUST be emitted when an account is approved to spend the bondholder's tokens in a different chain than the current chain
    * @param _owner the bondholder account
    * @param _spender the account to be allowed to spend bonds
    * @param _amount amount of bond tokens allowed by `_owner` to be spent by `_spender`
    * @param _destinationChainID The unique ID that identifies the destination Chain
    */
    event CrossChainApproval(address indexed _owner, address indexed _spender, uint256 _amount, bytes32 _destinationChainID);

    /**
    * @notice MUST be emitted when multiple accounts in the array `_spender` are approved or when the allowances of multiple accounts in the array `_spender` are reduced on the destination chain which MUST be different than the current chain
    * @param _owner bond token's owner
    * @param _spender array of accounts to be allowed to spend bonds
    * @param _amount array of amount of bond tokens allowed by _owner to be spent by _spender
    * @param _destinationChainID array of unique IDs that identify the destination Chain
    */
    event CrossChainApprovalBatch(address indexed _owner, address[] _spender, uint256[] _amount, bytes32[] _destinationChainID);

    // functions
    /**
    * @notice Authorizes the `_spender` account to manage a specified `_amount`of the bondholder bond tokens on the destination Chain
    * @param _spender account to be authorized by the bondholder
    * @param _amount amount of bond tokens to approve
    * @param _destinationChainID The unique ID that identifies the destination Chain.
    * @param _destinationContract The smart contract to interact with in the destination Chain
    */
    function crossChainApprove(address _spender, uint256 _amount, bytes32 _destinationChainID, address _destinationContract) external returns(bool);

    /**
    * @notice Authorizes multiple spender accounts in `_spender` to manage specified amounts in `_amount` of the bondholder tokens on the destination chain
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to approve
    * @param _destinationChainID array of unique IDs that identifies the destination Chain.
    * @param _destinationContract array of smart contracts to interact with in the destination Chain in order to Deposit or Mint tokens that are transferred.
    */
    function crossChainBatchApprove(address[] calldata _spender, uint256[] calldata _amount, bytes32[] calldata _destinationChainID, address[] calldata _destinationContract) external returns(bool);

    /**
    * @notice Decreases the allowance of `_spender` by a specified `_amount` on the destination Chain
    * @param _spender the address to be authorized by the bondholder
    * @param _amount amount of bond tokens to remove from allowance
    * @param _destinationChainID The unique ID that identifies the destination Chain.
    * @param _destinationContract The smart contract to interact with in the destination Chain in order to Deposit or Mint tokens that are transferred.
    */
    function crossChainDecreaseAllowance(address _spender, uint256 _amount, bytes32 _destinationChainID, address _destinationContract) external;

    /**
    * @notice Decreases the allowance of multiple spenders in `_spender` by corresponding amounts specified in the array `_amount` on the destination chain
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to decrease the allowance from
    * @param _destinationChainID array of unique IDs that identifies the destination Chain.
    * @param _destinationContract array of smart contracts to interact with in the destination Chain in order to Deposit or Mint tokens that are transferred.
    */
    function crossChainBatchDecreaseAllowance(address[] calldata _spender, uint256[] calldata _amount, bytes32[] calldata _destinationChainID, address[] calldata _destinationContract) external;

    /**
    * @notice Moves `_amount` bond tokens to the address `_to` from the current chain to another chain (e.g., moving tokens from Ethereum to Polygon).
    *         This methods also allows to attach data to the token that is being transferred
    * @param _to account to send bond tokens to
    * @param _amount amount of bond tokens to transfer
    * @param _data additional information provided by the bondholder
    * @param _destinationChainID The unique ID that identifies the destination Chain.
    * @param _destinationContract The smart contract to interact with in the destination Chain in order to Deposit or Mint bond tokens that are transferred.
    */
    function crossChainTransfer(address _to, uint256 _amount, bytes calldata _data, bytes32 _destinationChainID, address _destinationContract) external returns(bool);

    /**
    * @notice Transfers multiple bond tokens with amounts specified in the array `_amount` to the corresponding accounts in the array `_to` from the current chain to another chain (e.g., moving tokens from Ethereum to Polygon).
    *         This methods also allows to attach data to the token that is being transferred
    * @param _to array of accounts to send the bonds to
    * @param _amount array of amounts of bond tokens to transfer
    * @param _data array of additional information provided by the bondholder
    * @param _destinationChainID array of unique IDs that identify the destination Chains.
    * @param _destinationContract array of smart contracts to interact with in the destination Chains in order to Deposit or Mint bond tokens that are transferred.
    */
    function crossChainBatchTransfer(address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data, bytes32[] calldata _destinationChainID, address[] calldata _destinationContract) external returns(bool);

    /**
    * @notice Transfers `_amount` bond tokens from the `_from`account to the `_to` account from the current chain to another chain. The caller must be approved by the `_from` address.
    *         This methods also allows to attach data to the token that is being transferred
    * @param _from the bondholder address
    * @param _to the account to transfer bonds to
    * @param _amount amount of bond tokens to transfer
    * @param _data additional information provided by the token holder
    * @param _destinationChainID The unique ID that identifies the destination Chain.
    * @param _destinationContract The smart contract to interact with in the destination Chain in order to Deposit or Mint tokens that are transferred.
    */
    function crossChainTransferFrom(address _from, address _to, uint256 _amount, bytes calldata _data, bytes32 _destinationChainID, address _destinationContract) external returns(bool);

    /**
    * @notice Transfers several bond tokens with amounts specified in the array `_amount` from accounts in the array `_from` to accounts in the array `_to` from the current chain to another chain.
    *         The caller must be approved by the `_from` accounts to spend the corresponding amounts specified in the array `_amount`
    *         This methods also allows to attach data to the token that is being transferred
    * @param _from array of bondholder addresses
    * @param _to array of accounts to transfer bonds to
    * @param _amount array of amounts of bond tokens to transfer
    * @param _data array of additional information provided by the token holder
    * @param _destinationChainID array of unique IDs that identifies the destination Chain.
    * @param _destinationContract array of smart contracts to interact with in the destination Chain in order to Deposit or Mint tokens that are transferred.
    */
    function crossChainBatchTransferFrom(address[] calldata _from, address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data, bytes32[] calldata _destinationChainID, address[] calldata _destinationContract) external returns(bool);
}