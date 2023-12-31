// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC721, Strings} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

    error OnlyOwner();
    error InvalidOperation();

contract ZeroCouponBondsV1_AmetFinance is ERC721 {

    using SafeERC20 for IERC20;

    address public AMET_VAULT;
    string private _uri = "https://storage.amet.finance/contracts/";

    address private _issuer; // Bonds _issuer coupon

    uint256 private _total; // The amount of the bonds that can be issued(maximum)
    uint256 private _purchased; // The amount of bonds that were already _purchased
    uint256 private _redeemed; // The amount of bonds already _redeemed

    uint16 private _feePercentage;

    uint256 private _redeemLockPeriod; // Seconds after which user can redeem
    uint256 private immutable _issuanceDate; // The date when the contract was created

    address private immutable _investmentToken; // Bond purchasing token
    uint256 private immutable _investmentTokenAmount; // Bond purchasing amount

    address private immutable _interestToken; // Bond return token
    uint256 private immutable _interestTokenAmount; // Bond return amount

    mapping(uint256 tokenId => uint256) private _purchaseDates; // Bond purchase date

    modifier onlyIssuer() {
        require(msg.sender == _issuer, "Invalid Issuer");
        _;
    }

    modifier onlyVaultOwner() {
        require(msg.sender == AMET_VAULT, "Invalid Owner");
        _;
    }

    modifier isNotZeroAddress(address customAddress) {
        require(customAddress != address(0), "Invalid Address");
        _;
    }

    event ChangeOwner(address newAddress);
    event ChangeVaultAddress(address newAddress);

    event ChangeBaseURI(string uri);
    event ChangeFeePercentage(uint16 newFeePercentage);

    event BondsIssued(uint256 count);
    event BondsBurnt(uint256 count);
    event WithdrawRemaining(uint256 amount);
    event DecreasedRedeemLockPeriod(uint256 newRedeemLockPeriod);

    constructor(
        address vault,
        address issuer,
        uint256 total,
        uint256 redeemLockPeriod,
        address investmentToken,
        uint256 investmentTokenAmount,
        address interestToken,
        uint256 interestTokenAmount,
        uint16 feePercentage,
        string memory denomination
    ) ERC721(denomination, "ZCB") {
        AMET_VAULT = vault;
        _issuer = issuer;
        _total = total;
        _redeemLockPeriod = redeemLockPeriod;

        _investmentToken = investmentToken;
        _investmentTokenAmount = investmentTokenAmount;

        _interestToken = interestToken;
        _interestTokenAmount = interestTokenAmount;

        _feePercentage = feePercentage;
        _issuanceDate = block.timestamp;
    }

    //    ==== VAULT owner functions ====

    function changeVaultAddress(address _vaultAddress) external onlyVaultOwner isNotZeroAddress(_vaultAddress) {
        emit ChangeVaultAddress(_vaultAddress);
        AMET_VAULT = _vaultAddress;
    }

    function decreaseFeePercentage(uint16 percentage) external onlyVaultOwner {
        if (percentage >= _feePercentage) revert InvalidOperation();
        emit ChangeFeePercentage(percentage);
        _feePercentage = percentage;
    }

    function changeBaseURI(string memory uri) external onlyVaultOwner {
        emit ChangeBaseURI(uri);
        _uri = uri;
    }

    // ==================

    // ==== Issuer functions ====
    function decreaseRedeemLockPeriod(uint256 _newRedeemLockPeriod) external onlyIssuer {
        if (_newRedeemLockPeriod >= _redeemLockPeriod) revert InvalidOperation();
        emit DecreasedRedeemLockPeriod(_newRedeemLockPeriod);
        _redeemLockPeriod = _newRedeemLockPeriod;
    }

    function changeOwner(address _newAddress) external onlyIssuer isNotZeroAddress(_newAddress) {
        emit ChangeOwner(_newAddress);
        _issuer = _newAddress;
    }

    function issueBonds(uint256 count) external onlyIssuer {
        emit BondsIssued(count);
        _total = _total + count;
    }

    function burnUnsoldBonds(uint256 count) external onlyIssuer {
        uint256 newTotal = _total - count;
        if (_purchased > newTotal) revert InvalidOperation();

        _total = newTotal;
        emit BondsBurnt(count);
    }

    function withdrawRemaining() external onlyIssuer {
        IERC20 interest = IERC20(_interestToken);
        uint256 balance = interest.balanceOf(address(this)); // 1100
        uint256 totalNeeded = (_total - _redeemed) * _interestTokenAmount; // 1100
        if (totalNeeded >= balance) revert InvalidOperation();

        uint256 transferAmount = balance - totalNeeded;
        interest.safeTransfer(_issuer, transferAmount);
        emit WithdrawRemaining(transferAmount);
    }
    // ========

    // ==== Investor functions ====

    function purchase(uint256 count) external {
        uint256 currentPurchased = _purchased;

        if (currentPurchased + count > _total) revert InvalidOperation();
        uint256 totalPurchased = count * _investmentTokenAmount;

        for (uint256 index; index < count;) {
            uint256 tokenId = currentPurchased + index;
            _mint(msg.sender, tokenId);
            _purchaseDates[tokenId] = block.timestamp;
            unchecked {++index;}
        }

        unchecked {_purchased = _purchased + count;}

        uint256 totalFees = totalPurchased * _feePercentage / 1000;
        IERC20 investment = IERC20(_investmentToken);
        investment.safeTransferFrom(msg.sender, AMET_VAULT, totalFees);
        investment.safeTransferFrom(msg.sender, _issuer, totalPurchased - totalFees);
    }

    function redeem(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        uint256 totalRedemption = _interestTokenAmount * length;
        uint256 redeemLeft = block.timestamp - _redeemLockPeriod;

        IERC20 interest = IERC20(_interestToken);
        uint256 contractInterestBalance = interest.balanceOf(address(this));

        if (totalRedemption > contractInterestBalance) revert InvalidOperation();

        for (uint256 index; index < length;) {
            uint256 tokenId = tokenIds[index];

            if (ownerOf(tokenId) != msg.sender) revert OnlyOwner();
            if (_purchaseDates[tokenId] > redeemLeft) revert InvalidOperation();

            _burn(tokenId);
            delete _purchaseDates[tokenId];
            unchecked {++index;}
        }

        unchecked {_redeemed = _redeemed + length;}

        interest.safeTransfer(msg.sender, totalRedemption);
    }

    // ========

    //  ====== Utility functions ======

    function getInfo()
    external
    view
    returns (
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        uint256,
        address,
        uint256,
        uint16,
        uint256
    )
    {
        return (
            _issuer,
            _total,
            _purchased,
            _redeemed,
            _redeemLockPeriod,
            _investmentToken,
            _investmentTokenAmount,
            _interestToken,
            _interestTokenAmount,
            _feePercentage,
            _issuanceDate
        );
    }

    function getTokensPurchaseDates(uint256[] calldata tokenIds) external view returns (uint256[] memory) {
        uint256 tokenIdsLength = tokenIds.length;
        uint256[] memory purchaseDates = new uint256[](tokenIdsLength);

        for (uint256 id; id < tokenIdsLength;) {
            purchaseDates[id] = _purchaseDates[tokenIds[id]];
            unchecked {++id;}
        }
        return purchaseDates;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(_uri, Strings.toHexString(address(this)), ".json");
    }
}
