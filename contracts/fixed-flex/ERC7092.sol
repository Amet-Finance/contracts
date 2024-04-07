// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces/IERC7092.sol";
import "./BondStorage.sol";

contract ERC7092 is IERC7092, BondStorage {
    constructor(
        Types.Bond memory _bond
    ) {
        bonds = _bond;
    }

    function isin() external view returns(string memory) {
        return bonds.isin;
    }

    /**
    * @notice Returns the bond name
    */
    function name() external view returns(string memory) {
        return bonds.name;
    }

    /**
    * @notice Returns the bond symbol
    *         It is RECOMMENDED to represent the symbol as a combination of the issuer Issuer'shorter name and the maturity date
    *         Ex: If a company named Green Energy issues bonds that will mature on october 25, 2030, the bond symbol could be `GE30` or `GE2030` or `GE102530`
    */
    function symbol() external view returns(string memory) {
        return bonds.symbol;
    }

    /**
    * @notice Returns the bond currency. This is the contract address of the token used to pay and return the bond principal
    */
    function currency() external view returns(address) {
        return bonds.currency;
    }

    /**
    * @notice Returns the bond denominiation. This is the minimum amount in which the Bonds may be issued. It must be expressend in unit of the principal currency
    *         ex: If the denomination is equal to 1,000 and the currency is USDC, then the bond denomination is equal to 1,000 USDC
    */
    function denomination() external view returns(uint256) {
        return bonds.denomination;
    }

    /**
    * @notice Returns the issue volume (total debt amount). It is RECOMMENDED to express the issue volume in denomination unit.
    */
    function issueVolume() external view returns(uint256) {
        return bonds.issueVolume;
    }

    function totalSupply() public view returns(uint256) {
        uint256 _issueVolume = bonds.issueVolume;
        uint256 _denomination = bonds.denomination;

        return _issueVolume / _denomination;
    }

    /**
    * @notice Returns the bond interest rate. It is RECOMMENDED to express the interest rate in basis point unit.
    *         1 basis point = 0.01% = 0.0001
    *         ex: if interest rate = 5%, then coupon() => 500 basis points
    */
    function couponRate() external view returns(uint256) {
        return bonds.couponRate;
    }

    /**
    * @notice Returns the date when bonds were issued to investors. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function issueDate() external view returns(uint256) {
        return bonds.issueDate;
    }

    /**
    * @notice Returns the bond maturity date, i.e, the date when the pricipal is repaid. This is a Unix Timestamp like the one returned by block.timestamp
    *         The maturity date MUST be greater than the issue date
    */
    function maturityDate() external view returns(uint256) {
        return bonds.maturityDate;
    }

    /**
    * @notice Returns the principal of an account. It is RECOMMENDED to express the principal in the bond currency unit (USDC, DAI, etc...)
    * @param _account account address
    */
    function principalOf(address _account) external view returns(uint256) {
        return _principals[_account];
    }

    function balanceOf(address _account) public view returns(uint256) {
        uint256 _principal = _principals[_account];
        uint256 _denomination = bonds.denomination;

        return _principal / _denomination;
    }

    function balanceByPurchase(uint256 _purchaseIndex, address _account) public view returns(uint256) {
        return _balanceByPurchase[_purchaseIndex][_account];
    }

    function redeemBalance(uint256 _purchaseIndex, address _account) public view returns(uint256) {
        return _redeemBalance[_purchaseIndex][_account];
    }

    /**
    * @notice Returns the amount of tokens the `_spender` account has been authorized by the `_owner``
    *         acount to manage their bonds
    * @param _owner the bondholder address
    * @param _spender the address that has been authorized by the bondholder
    */
    function allowance(address _owner, address _spender) external view returns(uint256) {
        return _approvals[_owner][_spender];
    }

    // setter functions
    /**
    * @notice Authorizes `_spender` account to manage `_amount`of their bond tokens
    * @param _spender the address to be authorized by the bondholder
    * @param _amount amount of bond tokens to approve
    */
    function approve(address _spender, uint256 _amount) external returns(bool) {
        address _owner = msg.sender;
        _approve(_owner, _spender, _amount);

        emit Approval(_owner, _spender, _amount);

        return true;
    }

    /**
    * @notice Lowers the allowance of `_spender` by `_amount`
    * @param _spender the address to be authorized by the bondholder
    * @param _amount amount of bond tokens to remove from allowance
    */
    function decreaseAllowance(address _spender, uint256 _amount) external returns(bool) {
        address _owner = msg.sender;
        _decreaseAllowance(_owner, _spender, _amount);

        return true;
    }

    /**
    * @notice Moves `_amount` bonds to address `_to`. This methods also allows to attach data to the token that is being transferred
    * @param _to the address to send the bonds to
    * @param _amount amount of bond tokens to transfer
    * @param _data additional information provided by the token holder
    */
    function transfer(address _to, uint256 _amount, bytes calldata _data) external returns(bool) {
        address _from = msg.sender;
        _transfer(_from, _to, _amount, _data);

        return true;
    }

    /**
    * @notice Moves `_amount` bonds from an account that has authorized the caller through the approve function
    *         This methods also allows to attach data to the token that is being transferred
    * @param _from the bondholder address
    * @param _to the address to transfer bonds to
    * @param _amount amount of bond tokens to transfer.
    * @param _data additional information provided by the token holder
    */
    function transferFrom(address _from, address _to, uint256 _amount, bytes calldata _data) external returns(bool) {
        address _spender = msg.sender;
        _spendApproval(_from, _spender, _amount);
        _transfer(_from, _to, _amount, _data);

        return true;
    }

    // batch functions
    /**
    * @notice Authorizes multiple spender accounts to manage a specified `_amount` of the bondholder tokens
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to approve
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect these values to be present. The method is used to improve usability.
    */
    function batchApprove(address[] calldata _spender, uint256[] calldata _amount) external returns(bool) {
        address _owner = msg.sender;
        _batchApprove(_owner, _spender, _amount);

        return true;
    }

    /**
    * @notice Decreases the allowance of multiple spenders by corresponding amounts in `_amount`
    * @param _spender array of accounts to be authorized by the bondholder
    * @param _amount array of amounts of bond tokens to decrease the allowance from
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present. The method is used to decrease token allowance.
    */
    function batchDecreaseAllowance(address[] calldata _spender, uint256[] calldata _amount) external returns(bool) {
        address _owner = msg.sender;
        _batchDecreaseAllowance(_owner, _spender, _amount);

        return true;
    }

    /**
    * @notice Transfers multiple bonds with amounts specified in the array `_amount` to the corresponding accounts in the array `_to`, with the option to attach additional data
    * @param _to array of accounts to send the bonds to
    * @param _amount array of amounts of bond tokens to transfer
    * @param _data array of additional information provided by the token holder
    *
    * OPTIONAL - interfaces and other contracts MUST NOT expect this function to be present.
    */
    function batchTransfer(address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data) external returns(bool) {
        address[] memory _from;
        for(uint256 i; i < _to.length; i++) {
            _from[i] = msg.sender;
        }

        _batchTransfer(_from, _to, _amount, _data);

        return true;
    }

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
    function batchTransferFrom(address[] calldata _from, address[] calldata _to, uint256[] calldata _amount, bytes[] calldata _data) external returns(bool) {
        address _spender = msg.sender;
        _batchSpendApproval(_from, _spender, _amount);
        _batchTransfer(_from, _to, _amount, _data);

        return true;
    }

    function _mint(address _to, uint256 _amount, uint256 _purchaseIndex) internal {
        require(_to != address(0), "ERC7092: invalid recipient");
        uint256 _denomination = bonds.denomination;
        uint256 _issueVolume = bonds.issueVolume;
        uint256 principalOfTo = _principals[_to];
        uint256 balPurchase =  _balanceByPurchase[_purchaseIndex][_to];

        unchecked {
            _principals[_to] = principalOfTo + _amount * _denomination;
            _balanceByPurchase[_purchaseIndex][_to] = balPurchase + _amount;
            bonds.issueVolume = _issueVolume + _amount * _denomination;
        }

        emit Transfer(address(0), _to, _amount);
    }

    function _burn(address _from, uint256 _amount, uint256 _purchaseIndex) internal {
        require(_from != address(0), "ERC7092: invalid address");
        uint256 _denomination = bonds.denomination;
        uint256 principalOfFrom = _principals[_from];
        uint256 balPurchase =  _balanceByPurchase[_purchaseIndex][_from];
        uint256 _redeemBal = _redeemBalance[_purchaseIndex][_from];

        require(_amount <= balPurchase, "ERC7092: invalid amount");

        unchecked {
            _principals[_from] = principalOfFrom - _amount * _denomination;
            _balanceByPurchase[_purchaseIndex][_from] = balPurchase - _amount;
            _redeemBalance[_purchaseIndex][_from] = _redeemBal + _amount;
        }

        emit Transfer(_from, address(0), _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "wrong address");
        require(_spender != address(0), "wrong address");
        require(_amount > 0, "invalid amount");

        uint256 _approval = _approvals[_owner][_spender];
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        uint256 _principal = _principals[_owner];
        uint256 _balance = _principal / _denomination;

        require(block.timestamp < _maturityDate, "matured");
        require(_amount <= _balance, "insufficient balance");
        require((_amount * _denomination) % _denomination == 0, "invalid amount");

        _approvals[_owner][_spender]  = _approval + _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _decreaseAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "wrong address");
        require(_spender != address(0), "wrong address");
        require(_amount > 0, "invalid amount");

        uint256 _approval = _approvals[_owner][_spender];
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        require(block.timestamp < _maturityDate, "matured");
        require(_amount <= _approval, "insufficient approval");
        require((_amount * _denomination) % _denomination == 0, "invalid amount");

        _approvals[_owner][_spender]  = _approval - _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) internal virtual {
        require(_from != address(0), "wrong address");
        require(_to != address(0), "wrong address");
        require(_amount > 0, "invalid amount");

        uint256 principal = _principals[_from];
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        uint256 _principal = _principals[_from];
        uint256 _balance = _principal / _denomination;

        require(block.timestamp < _maturityDate, "matured");
        require(_amount <= _balance, "insufficient balance");
        require((_amount * _denomination) % _denomination == 0, "invalid amount");

        uint256 principalTo = _principals[_to];

        _beforeBondTransfer(_from, _to, _amount, _data);

        unchecked {
            uint256 _principalTransferred = _amount * _denomination;

            _principals[_from] = principal - _principalTransferred;
            _principals[_to] = principalTo + _principalTransferred;
        }

        _afterBondTransfer(_from, _to, _amount, _data);

        emit Transfer(_from, _to, _amount);
    }

    function _spendApproval(address _from, address _spender, uint256 _amount) internal virtual {
        uint256 currentApproval = _approvals[_from][_spender];
        require(_amount <= currentApproval, "insufficient allowance");

        unchecked {
            _approvals[_from][_spender] = currentApproval - _amount;
        }
   }

   function _batchApprove(
    address _owner,
    address[] calldata _spender,
    uint256[] calldata _amount
   ) internal virtual {
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        uint256 _principal = _principals[_owner];
        uint256 _balance = _principal / _denomination;

        require(_owner != address(0), "wrong address");
        require(block.timestamp < _maturityDate, "matured");

        uint256 totalAmount;
        for(uint256 i; i < _spender.length; i++) {
            totalAmount = totalAmount + _amount[i];

            require(_spender[i] != address(0), "wrong address");
            require(_amount[i] > 0, "invalid amount");
            require(totalAmount <= _balance, "insufficient balance");
            require((totalAmount * _denomination) % _denomination == 0, "invalid amount");

            uint256 _approval = _approvals[_owner][_spender[i]];

            _approvals[_owner][_spender[i]]  = _approval + _amount[i];
        }

        emit ApprovalBatch(_owner, _spender, _amount);
    }

    function _batchDecreaseAllowance(
        address _owner,
        address[] calldata _spender,
        uint256[] calldata _amount
    ) internal virtual {
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        require(_owner != address(0), "wrong address");
        require(block.timestamp < _maturityDate, "matured");

        for(uint256 i; i < _spender.length; i++) {
            uint256 _approval = _approvals[_owner][_spender[i]];

            require(_amount[i] <= _approval, "insufficient approval");
            require(_amount[i] > 0, "invalid amount");
            require((_amount[i] * _denomination) % _denomination == 0, "invalid amount");

            _approvals[_owner][_spender[i]]  = _approval - _amount[i];
        }

        emit ApprovalBatch(_owner, _spender, _amount);
    }

    function _batchTransfer(
        address[] memory _from,
        address[] memory _to,
        uint256[] calldata _amount,
        bytes[] calldata _data
    ) internal virtual {
        uint256 _denomination = bonds.denomination;
        uint256 _maturityDate = bonds.maturityDate;

        require(block.timestamp < _maturityDate, "matured");

        for(uint256 i; i < _from.length; i++) {
            uint256 principal = _principals[_from[i]];

            uint256 _principal = _principals[_from[i]];
            uint256 _balance = _principal / _denomination;

            require(_from[i] != address(0), "wrong address");
            require(_to[i] != address(0), "wrong address");
            require(_amount[i] > 0, "invalid amount");
            require(_amount[i] <= _balance, "insufficient balance");
            require((_amount[i] * _denomination) % _denomination == 0, "invalid amount");

            uint256 principalTo = _principals[_to[i]];

            _batchBeforeBondTransfer(_from, _to, _amount, _data);

            unchecked {
                uint256 _principalTransferred = _amount[i] * _denomination;

                _principals[_from[i]] = principal - _principalTransferred;
                _principals[_to[i]] = principalTo + _principalTransferred;
            }

            _batchAfterBondTransfer(_from, _to, _amount, _data);
        }

        emit TransferBatch(_from, _to, _amount);
    }

    function _batchSpendApproval(
        address[] calldata _from,
        address _spender,
        uint256[] calldata _amount
    ) internal virtual {
        for(uint256 i; i < _from.length; i++) {
            uint256 currentApproval = _approvals[_from[i]][_spender];
            require(_amount[i] <= currentApproval, "insufficient allowance");

            unchecked {
                _approvals[_from[i]][_spender] = currentApproval - _amount[i];
            }
        }
    }

    function _beforeBondTransfer(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) internal virtual {}

    function _afterBondTransfer(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) internal virtual {}

    function _batchBeforeBondTransfer(
        address[] memory _from,
        address[] memory _to,
        uint256[] calldata _amount,
        bytes[] calldata _data
    ) internal virtual {}

    function _batchAfterBondTransfer(
        address[] memory _from,
        address[] memory _to,
        uint256[] calldata _amount,
        bytes[] calldata _data
    ) internal virtual {}
}