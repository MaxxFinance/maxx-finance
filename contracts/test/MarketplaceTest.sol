// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IStake} from "../interfaces/IStake.sol";

/// Stake not listed for sale on the marketplace
error StakeNotListed();

/// Not enough Matic sent with the transaction
error InsufficientValue();

/// Not owner or approved as operator of the stake
error NotApproved();

/// Fee percentage can't be greater than 10%
error FeeTooHigh();

/// Listing has expired
error ListingExpired();

/// @title Maxx Finance Stake Marketplace
/// @author Alta Web3 Labs - SonOfMosiah
contract MarketplaceTest is Ownable {
    uint16 private constant TEST_TIME_FACTOR = 168; // Test contract runs 168x faster (1 hour = 1 week)
    /// Maxx Finance staking contract
    IStake public maxxStake;

    /// The percentage of transactions to be paid to the marketplace (e.g. 25 = 2.5%)
    uint16 public feePercentage; // percentage * 10 (e.g. 100 = 10%)
    uint16 private constant MAX_FEE_PERCENTAGE = 100; // max fee percentage = 10%
    uint16 private constant FEE_FACTOR = 1000;

    /// mapping of stake id to their desired sellPrice
    mapping(uint256 => uint256) public sellPrice;

    /// mapping of stake id to their listing
    mapping(uint256 => Listing) public listings;

    /// @notice Emitted when stake is listed to the market
    /// @param user The user who listed the stake
    /// @param stakeId The id of the stake
    /// @param amount The amount asked for the stake
    event List(address indexed user, uint256 indexed stakeId, uint256 amount);

    /// @notice Emitted when stake is delisted from the market
    /// @param user The user who listed the stake
    /// @param stakeId The id of the stake
    event Delist(address indexed user, uint256 indexed stakeId);

    /// @notice Emitted when stake is purhased off the market
    /// @param user The user who purchased the stake
    /// @param stakeId The id of the stake
    /// @param amount The purchase amount
    event Purchase(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount
    );

    struct Listing {
        address lister;
        uint256 amount;
        uint256 endTime;
    }

    constructor(address _maxxStake) {
        maxxStake = IStake(_maxxStake);
    }

    /// @notice Function to list stake on the market
    /// @param _stakeId The id of the stake to list
    /// @param _amount The price of the stake in the native coin
    function listStake(
        uint256 _stakeId,
        uint256 _amount,
        uint256 _duration
    ) external {
        address stakeOwner = maxxStake.ownerOf(_stakeId);
        if (
            msg.sender != stakeOwner &&
            !maxxStake.isApprovedForAll(stakeOwner, msg.sender)
        ) {
            revert NotApproved();
        }
        sellPrice[_stakeId] = _amount;
        listings[_stakeId] = Listing(
            msg.sender,
            _amount,
            block.timestamp + (_duration / TEST_TIME_FACTOR)
        );
        emit List(msg.sender, _stakeId, _amount);
    }

    /// @notice Function to delist stake from the market
    /// @param _stakeId The id of the stake to delist
    function delistStake(uint256 _stakeId) external {
        address stakeOwner = maxxStake.ownerOf(_stakeId);
        if (
            msg.sender != stakeOwner &&
            !maxxStake.isApprovedForAll(stakeOwner, msg.sender)
        ) {
            revert NotApproved();
        }
        // sellPrice[_stakeId] = 0;
        delete sellPrice[_stakeId]; // TODO Which is cheaper?
        delete listings[_stakeId];
        emit Delist(msg.sender, _stakeId);
    }

    /// @notice Function to buy a stake from the market
    /// @param _stakeId The id of the stake to buy
    function buyStake(uint256 _stakeId) external payable {
        address stakeOwner = maxxStake.ownerOf(_stakeId);
        Listing memory listing = listings[_stakeId];

        if (listing.lister != stakeOwner) {
            revert StakeNotListed();
        }

        if (listing.endTime < block.timestamp) {
            revert ListingExpired();
        }

        if (msg.value < sellPrice[_stakeId]) {
            revert InsufficientValue();
        }

        uint256 transferFee = (msg.value * feePercentage) / FEE_FACTOR;
        uint256 amount = msg.value - transferFee;

        payable(stakeOwner).transfer(amount);

        // sellPrice[_stakeId] = 0;
        delete sellPrice[_stakeId]; // TODO Which is cheaper?
        maxxStake.transferFrom(stakeOwner, msg.sender, _stakeId);
        emit Purchase(msg.sender, _stakeId, msg.value);
    }

    /// @notice Function to set the fee percentage for the marketplace
    /// @param _feePercentage The percentage of the transaction to be paid to the marketplace (e.g. 25 = 2.5%)
    function setFeePercentage(uint16 _feePercentage) external onlyOwner {
        if (_feePercentage > MAX_FEE_PERCENTAGE) {
            revert FeeTooHigh();
        }
        feePercentage = _feePercentage;
    }

    /// @notice Function to transfer Matic from this contract to address from input
    /// @param _to address of transfer recipient
    /// @param _amount amount of Matic to be transferred
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }
}
