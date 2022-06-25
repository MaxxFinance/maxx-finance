// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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
    /// @param amount The amount of MAXX unstaked
    event Unstake(address indexed user, uint256 amount);

    /// @notice Emitted when stake is transferred
    /// @param oldOwner The user transferring the stake
    /// @param newOwner The user receiving the stake
    event Transfer(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when interest is scraped early
    /// @param user The user who scraped interest
    /// @param amount The amount of interest scraped
    event ScrapeInterest(address indexed user, uint256 amount);

    /// @notice Emitted when stake is listed to the market
    /// @param user The user who listed the stake
    /// @param stakeId The id of the stake
    /// @param amount The amount asked for the stake
    event List(address indexed user, uint256 indexed stakeId, uint256 amount);

    MaxxFinance public maxx;
    uint256 immutable launchDate;
    uint8 constant LATE_DAYS = 14;
    uint16 constant MIN_STAKE_DAYS = 7;
    uint16 constant MAX_STAKE_DAYS = 3333;
    uint16 constant BASE_INFLATION = 10; // 10%
    uint16 constant BASE_INFLATION_FACTOR = 100;
    uint16 constant PERCENT_FACTOR = 10000;
    uint256 constant MAGIC_NUMBER = 1111;

    uint256 public idCounter;
    uint256 public total_shares;
    uint256 public total_stakes_alltime;
    uint256 public total_stakes_active;
    uint256 public total_stakes_withdrawn;
    uint256 public total_stakes_matured; // who is going to pay for the transaction to update this?
    uint256 public total_staked_outstanding_interest; // who is going to pay for the transaction to update this?

    IERC721 public nft; // import nft contract or generic ERC721 interface for balanceOf()

    mapping(uint256 => StakeData) public stakes;
    mapping(uint256 => uint256) public withdrawnAmounts;
    mapping(uint256 => bool) public market;
    mapping(uint256 => uint256) public sellPrice;

    struct StakeData {
        address owner;
        bytes32 name; // 32 letters max
        uint256 amount;
        uint256 shares;
        uint256 duration;
        uint256 startDate;
    }

    constructor(address _maxx, uint256 _launchDate) {
        maxx = MaxxFinance(_maxx);
        launchDate = _launchDate;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _days The number of days to stake (min 5, max 3333)
    /// @param _amount The amount of MAXX to stake
    function stake(uint16 _days, uint256 _amount) public {
        require(_days >= MIN_STAKE_DAYS, "Stake too short");
        require(_days <= MAX_STAKE_DAYS, "Stake too long");

        maxx.burnFrom(msg.sender, _amount); // burn the tokens

        uint256 shares = _calcShares(_days, _amount);

        if (nft.balanceOf(msg.sender) > 0) {
            // TODO: calculate bonus shares
        }

        total_shares += shares;
        total_stakes_alltime++;
        total_stakes_active++;

        uint256 duration = _days * 1 days;

        stakes[idCounter] = StakeData(msg.sender, bytes32(idCounter), _amount, shares, duration, block.timestamp);
        idCounter++;
        emit Stake(msg.sender, _days, _amount);
    }

    /// @notice Function to unstake MAXX
    function unstake(uint256 _stakeId) public {
        StakeData memory tStake = stakes[_stakeId];
        require(tStake.owner == msg.sender, "You are not the owner of this stake");
        total_stakes_withdrawn++;
        total_stakes_active--;

        uint256 withdrawableAmount;
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);
        interestToDate = interestToDate - withdrawnAmounts[_stakeId]; // TODO: check if this affects the ensuing math calculations

        if (daysServed < (tStake.duration / 1 days)) { // unstaking early
            // fee assessed
            withdrawableAmount = (tStake.amount + interestToDate) * daysServed / (tStake.duration / 1 days);
        } else if (daysServed > (tStake.duration / 1 days) + LATE_DAYS) { // unstaking late
            // fee assessed
            uint256 daysLate = daysServed - (tStake.duration / 1 days) - LATE_DAYS;
            uint8 penaltyPercentage = uint8(PERCENT_FACTOR * daysLate / 365);
            withdrawableAmount = (tStake.amount + interestToDate) * (PERCENT_FACTOR - penaltyPercentage / 100) / 100;
        } else { // unstaking on time
            withdrawableAmount = tStake.amount + interestToDate;
        }
        withdrawnAmounts[_stakeId] = withdrawableAmount;
        maxx.mint(msg.sender, withdrawableAmount); // mint the tokens
        emit Unstake(msg.sender, withdrawableAmount);
    }

    /// @notice Function to change stake to maximum duration without penalties
    /// @param _stakeId The id of the stake to change
    function maxShare(uint256 _stakeId) external {

    }

    /// @notice Function to restake without penalties
    /// @param _stakeId The id of the stake to restake
    /// @param _topUpAmount The amount of MAXX to top up the stake
    function restake(uint256 _stakeId, uint256 _topUpAmount) external {
        StakeData memory tStake = stakes[_stakeId];
        require(tStake.owner == msg.sender, "You are not the owner of this stake");
        uint256 maturation = tStake.startDate + tStake.duration;
        require(block.timestamp > maturation, "You cannot restake a stake that is not matured");
        require(_topUpAmount <= maxx.balanceOf(msg.sender), "You cannot top up with more MAXX than you have");
        maxx.transferFrom(msg.sender, address(this), _topUpAmount); // burn the tokens
        tStake.amount += _topUpAmount;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        total_shares -= tStake.shares;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        total_shares += tStake.shares;
        emit Stake(msg.sender, durationInDays, _topUpAmount);
    }

    /// @notice Function to list stake on the market
    /// @param _stakeId The id of the stake to list
    /// @param _amount The price of the stake in the native coin
    function listStake(uint256 _stakeId, uint256 _amount) external {
        StakeData memory tStake = stakes[_stakeId];
        require(tStake.owner == msg.sender, "You are not the owner of this stake");
        market[_stakeId] = true;
        sellPrice[_stakeId] = _amount;
        emit List(msg.sender, _stakeId, _amount);
    }

    /// @notice Function to buy a stake from the market
    /// @param _stakeId The id of the stake to buy
    function buyStake(uint256 _stakeId) external payable {
        StakeData memory tStake = stakes[_stakeId];
        require(tStake.owner == msg.sender, "You are not the owner of this stake");
        require(market[_stakeId], "This stake is not for sale");
        require(msg.value == sellPrice[_stakeId]);
        market[_stakeId] = false;
        sellPrice[_stakeId] = 0;
        _transfer(payable(tStake.owner), msg.value);
        _transferStake(_stakeId, msg.sender);
    }

    /// @notice Function to transfer stake ownership
    /// @param _stakeId The id of the stake
    function transferStake(uint256 _stakeId, address _to) external {
        require(!market[_stakeId], "Stake is on the market");
        _transferStake(_stakeId, _to);
    }

    /// @notice Function to withdraw interest early from a stake
    /// @param _stakeId The id of the stake
    function scrapeInterest(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        require(tStake.owner == msg.sender, "You are not the owner of this stake");
        require(!market[_stakeId], "Stake is on the market");
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);

        // TODO: add penalties for early withdrawal
        uint256 withdrawableAmount;
        withdrawnAmounts[_stakeId] = withdrawableAmount;
        maxx.mint(msg.sender, withdrawableAmount);
        emit ScrapeInterest(msg.sender, interestToDate);
    }

    /// @notice This function changes the name of a stake
    /// @param _stakeId The id of the stake
    /// @param _name The new name of the stake
    function changeStakeName(uint256 _stakeId, bytes32 _name) external {
        StakeData memory tStake = stakes[_stakeId];
        require(msg.sender == tStake.owner, "Only owner can change stake name");

        tStake.name = _name; // update variables in memory
        stakes[_stakeId] = tStake; // push data to storage
    }

    /// @notice Function to stake MAXX from amplifier contract
    /// @dev Must approve MAXX before staking
    /// @param _amount The amount of MAXX to stake
    function amplifierStake(uint16 _days, uint256 _amount) external {
        maxx.burnFrom(msg.sender, _amount); // burn the tokens

        uint256 shares = _calcShares(_days, _amount);
        if (_days >= 365) {
            // TODO: calculate the bonus amount of shares
            // e.g. shares = shares * 10%
        }
        
        total_shares += shares;
        total_stakes_alltime++;
        total_stakes_active++;

        uint256 duration = _days * 1 days;

        // Uses tx.origin as the owner of the stake -> owner must be an external account
        stakes[idCounter] = StakeData(tx.origin, bytes32(idCounter), _amount, shares, duration, block.timestamp);
        idCounter++;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _amount The amount of MAXX to stake
    function freeClaimStake(uint256 _amount) public {
        maxx.burnFrom(msg.sender, _amount); // burn the tokens

        uint256 shares = _calcShares(365, _amount);
        total_shares += shares;
        total_stakes_alltime++;
        total_stakes_active++;

        uint256 duration = 365 days;

        // Uses tx.origin as the owner of the stake -> owner must be an external account
        stakes[idCounter] = StakeData(tx.origin, bytes32(idCounter), _amount, shares, duration, block.timestamp);
        idCounter++;
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `launchDate`
    function getDaysSinceLaunch() public view returns (uint256 day) {
        day = (block.timestamp - launchDate) / 60 / 60 / 24;
        return day;
    }

    function _transferStake(uint256 _stakeId, address _to) internal {
        StakeData memory tStake = stakes[_stakeId];
        tStake.owner = _to; // update variables in memory
        stakes[_stakeId] = tStake; // push data to storage
        emit Transfer(msg.sender, _to);
    }

    /// @dev Calculate shares using following formula: (amount / (2-SF)) + (((amount / (2-SF)) * (Duration-1)) / MN)
    /// @return shares The number of shares for the full-term stake
    function _calcShares(uint16 duration, uint256 _amount) internal view returns (uint256 shares) {
        uint256 SF = _getShareFactor();
        shares = (_amount / (2 - SF)) + (((_amount / (2 - SF)) * (duration - 1)) / MAGIC_NUMBER);
        return shares;
    }

    /// @return shareFactor The current share factor
    function _getShareFactor() internal view returns (uint256 shareFactor) {
        shareFactor = 1 - (getDaysSinceLaunch() / 3333);
        return shareFactor;
    }

    /// @dev Calculate interest for a given number of shares and duration
    /// @return interestToDate The interest accrued to date
    function _calcInterestToDate(uint256 _stakeTotalShares, uint256 _daysServed, uint256 _duration) internal pure returns (uint256 interestToDate) {
        uint256 stakeDuration = _duration / 1 days;
        uint256 fullDurationInterest = _stakeTotalShares * (stakeDuration / 365) * BASE_INFLATION / BASE_INFLATION_FACTOR;

        uint256 currentDurationInterest = _daysServed * _stakeTotalShares * (_daysServed / stakeDuration) * BASE_INFLATION / BASE_INFLATION_FACTOR / stakeDuration;

        if (currentDurationInterest > fullDurationInterest) {
            interestToDate = fullDurationInterest;
        } else {
            interestToDate = currentDurationInterest;
        }
        return interestToDate;
    }

    /// @notice Function to transfer Fantom from this contract to address from input
    /// @param _to address of transfer recipient
    /// @param _amount amount of Fantom to be transferred
    function _transfer(address payable _to, uint256 _amount) internal {
         // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }
}