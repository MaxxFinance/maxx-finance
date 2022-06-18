// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { MaxxFinance } from "./MaxxFinance.sol";

/// @author Alta Web3 Labs
contract MaxxStake is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when MAXX is staked
    /// @param user The user staking MAXX
    /// @param numDays The number of days staked
    /// @param amount The amount of MAXX staked
    event Stake(address indexed user, uint16 numDays, uint256 amount);

    /// @notice Emitted when MAXX is unstaked
    /// @param user The user unstaking MAXX
    /// @param numDays The number of days MAXX was staked
    /// @param amount The amount of MAXX unstaked
    event Unstake(address indexed user, uint16 numDays, uint256 amount);

    MaxxFinance public maxx;
    uint16 constant MIN_STAKE_DAYS = 7;
    uint16 constant MAX_STAKE_DAYS = 3333;
    uint256 immutable launchDate;

    uint256 public total_shares;
    uint256 public total_stakes_alltime;
    uint256 public total_stakes_active;
    uint256 public total_stakes_matured; // who is going to pay for the transaction to update this?
    uint256 public total_stakes_withdrawn;
    uint256 public total_staked_outstanding_interest; // who is going to pay for the transaction to update this?

    uint256 constant private magicNumber = 1111;
    uint256 public idCounter;

    mapping(uint256 => StakeData) public stakes;

    struct StakeData {
        address owner;
        bytes32 name;
        uint256 shares;
        uint256 time;
        uint256 startDate;
    }

    constructor(address _maxx, uint256 _launchDate) {
        maxx = MaxxFinance(_maxx);
        launchDate = _launchDate;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _days The number of days to stake (min 5, max 3333)
    function stake(uint16 _days, uint256 _amount, bytes32 _name) public {
        require(_days >= MIN_STAKE_DAYS, "Stake too short");
        require(_days <= MAX_STAKE_DAYS, "Stake too long");

        maxx.burnFrom(msg.sender, _amount); // burn the tokens

        uint256 shares = _calcShares(_days, _amount);
        uint256 time = _days * 1 days;

        stakes[idCounter] = StakeData(msg.sender, _name, shares, time, block.timestamp);
        idCounter++;

        // TODO: potentially emit an ERC 721 NFT to track stake and easily transfer ownership
    }

    /// @notice Function to unstake MAXX
    function unstake() public {
        // if (block.timestamp < stakeDate) { // unstaking early
        //     // fee assessed
        // } else if (block.timestamp > stakeDate + lateDays) {
        //     // fee assessed
        // }

        //TODO: mint the tokens at the end
    }

    /// @notice Function to transfer stake ownership
    /// @param _stakeId The id of the stake
    function transferStake(uint256 _stakeId, address _to) public {
        StakeData memory tStake = stakes[_stakeId];
        require(msg.sender == tStake.owner, "Only owner can transfer stake");

        tStake.owner = _to; // update variables in memory
        stakes[_stakeId] = tStake; // push data to storage

        // TODO: include a transfer fee if requested.

    }

    function _calcShares(uint16 _days, uint256 _amount) internal pure returns (uint256) {
        // TODO: calculate shares using formula: (amount / (2-SF)) + (((amount / (2-SF)) * (Duration-1)) / MN)
        uint256 shares = _amount * _days;
        return shares;
    }

    /// @return shareFactor The current share factor
    function _getShareFactor() internal view returns (uint256 shareFactor) {
        shareFactor = 1 - (getDaysSinceLaunch() / 3333);
        return shareFactor;
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `launchDate`
    function getDaysSinceLaunch() public view returns (uint256 day) {
        day = (block.timestamp - launchDate) / 60 / 60 / 24;
        return day;
    }
}