// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "hardhat/console.sol";

import { IStake } from './interfaces/IStake.sol';

/// Stake not listed for sale on the marketplace
error StakeNotListed();

/// Not enough Matic sent with the transaction
error InsufficientValue();

/// Not the owner the stake
error NotOwner();

/// Marketplace not approved to transfer stake
error NotApproved();

/// Fee percentage can't be greater than 10%
error FeeTooHigh();

/// Listing has expired
error ListingExpired();

/// @title Maxx Finance Stake Marketplace
/// @author Alta Web3 Labs
contract Marketplace is Ownable {

    /// @notice Emitted when stake is listed to the market
    /// @param user The user who listed the stake
    /// @param stakeId The id of the stake
    /// @param amount The amount asked for the stake
    event List(address indexed user, uint256 indexed stakeId, uint256 amount);

    /// @notice Emitted when stake is purhased off the market
    /// @param user The user who purchased the stake
    /// @param stakeId The id of the stake
    /// @param amount The purchase amount
    event Purchase(address indexed user, uint256 indexed stakeId, uint256 amount);

    /// Maxx Finance staking contract
    IStake public maxxStake;

    /// The percentage of transactions to be paid to the marketplace (e.g. 25 = 2.5%)
    uint16 public feePercentage;
    uint16 constant FEE_FACTOR = 1000;

    /// mapping of stake id to their desired sellPrice
    mapping(uint256 => uint256) public sellPrice;
    
    /// mapping of stake id to their listing
    mapping(uint256 => Listing) public listings;

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
    function listStake(uint256 _stakeId, uint256 _amount, uint256 _duration) external {
        // require approval
        address stakeOwner = maxxStake.stakeOwner(_stakeId);
        if (!maxxStake.allowance(stakeOwner, address(this), _stakeId)) {
            revert NotApproved();
        }
        if (msg.sender != stakeOwner) {
            revert NotOwner();
        }
        sellPrice[_stakeId] = _amount;
        listings[_stakeId] = Listing(msg.sender, _amount, block.timestamp + _duration);
        emit List(msg.sender, _stakeId, _amount);
    }

    /// @notice Function to buy a stake from the market
    /// @param _stakeId The id of the stake to buy
    function buyStake(uint256 _stakeId) external payable {
        address stakeOwner = maxxStake.stakeOwner(_stakeId);
        if (!maxxStake.allowance(stakeOwner, address(this), _stakeId)) {
            revert NotApproved();
        }

        Listing memory listing = listings[_stakeId];

        if (listing.lister != stakeOwner) {
            revert StakeNotListed();
        }

        if (listing.endTime < block.timestamp) {
            revert ListingExpired();
        }

        if (msg.value < sellPrice[_stakeId]) { // TODO: send the extra to the seller or keep in contract? change following msg.value to sellPrice
            revert InsufficientValue();
        }

        uint256 transferFee = msg.value * feePercentage / FEE_FACTOR;
        uint256 amount = msg.value - transferFee;

        payable(stakeOwner).transfer(amount);

        sellPrice[_stakeId] = 0;
        require(maxxStake.transferFrom(stakeOwner, msg.sender, _stakeId));
        emit Purchase(msg.sender, _stakeId, msg.value);
    }

    /// @notice Function to set the fee percentage for the marketplace
    /// @param _feePercentage The percentage of the transaction to be paid to the marketplace (e.g. 25 = 2.5%)
    function setFeePercentage(uint16 _feePercentage) external onlyOwner {
        if (_feePercentage > 100) {
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