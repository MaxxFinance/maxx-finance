// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

import { MaxxFinance } from "./MaxxFinance.sol";

/// Not the owner the stake
error NotOwner();

/// The stake is already approved
error AlreadyApproved();

/// The spender is not approved to transfer the stake
error UnauthorizedTransfer();

/// Cannot stake less than {MIN_STAKE_DAYS} days
error StakeTooShort();

/// Cannot stake more than {MAX_STAKE_DAYS} days
error StakeTooLong();

/// Address does not own enough MAXX tokens
error InsufficientMaxx();

/// Stake has not yet completed
error StakeNotComplete();

/// @title Maxx Finance staking contract
/// @author Alta Web3 Labs - SonOfMosiah
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

    /// @notice Emitted when the name of a stake is changed
    /// @param stakeId The id of the stake
    /// @param name The new name of the stake
    event StakeNameChange(uint256 stakeId, string name);

    /// Maxx Finance token
    MaxxFinance public maxx;
    uint256 immutable launchDate;
    uint8 constant LATE_DAYS = 14;
    uint16 constant MIN_STAKE_DAYS = 7;
    uint16 constant MAX_STAKE_DAYS = 3333;
    uint16 constant BASE_INFLATION = 10; // 10%
    uint16 constant BASE_INFLATION_FACTOR = 100;
    uint256 constant PERCENT_FACTOR = 10000000000; // was 10,000 now 1,000,000,000
    uint256 constant MAGIC_NUMBER = 1111;

    /// stake id for next created stake
    uint256 public idCounter;

    /// amount of shares all time
    uint256 public totalShares;

    /// alltime stakes
    uint256 public totalStakesAlltime;

    /// all active stakes
    uint256 public totalStakesActive;

    /// number of withdraw stakes
    uint256 public totalStakesWithdrawn;

    /// number of matured stakes
    uint256 public totalStakesMatured; // who is going to pay for the transaction to update this?

    /// amount of accrued interest
    uint256 public totalStakedOutstandingInterest; // who is going to pay for the transaction to update this?

    /// percentage of nft bonus
    uint8 public nftBonusPercentage;

    /// bonus nft
    IERC721 public nft; // import nft contract or generic ERC721 interface for balanceOf()

    /// address of the freeClaim contract
    address public freeClaim;

    /// address of the liquidityAmplifier contract
    address public liquidityAmplifier;

    /// mapping of stake id to stake
    mapping(uint256 => StakeData) public stakes;

    /// mapping of stake id to withdrawn amounts
    mapping(uint256 => uint256) public withdrawnAmounts;

    /// @notice mapping of stake allowances
    mapping(address => mapping(uint256 => mapping(address => bool))) public allowances;

    mapping(uint256 => address) public stakeOwner;

    struct StakeData {
        address owner;
        string name; // 32 letters max
        uint256 amount;
        uint256 shares;
        uint256 duration;
        uint256 startDate;
    }

    constructor(address _maxx, uint256 _launchDate, address _nft) {
        maxx = MaxxFinance(_maxx);
        launchDate = _launchDate;
        nft = IERC721(_nft);
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    function stake(uint16 _numDays, uint256 _amount) external {
        console.log("enter stake");

        if (_numDays < MIN_STAKE_DAYS) {
            revert StakeTooShort();
        } else if (_numDays > MAX_STAKE_DAYS) {
            revert StakeTooLong();
        }

        require(maxx.transferFrom(msg.sender, address(this), _amount)); // transfer tokens to this contract

        uint256 shares = _calcShares(_numDays, _amount);

        if (nft.balanceOf(msg.sender) > 0) {
            shares = shares * (100 + nftBonusPercentage) / 100;
        }

        totalShares += shares;
        totalStakesAlltime++;
        totalStakesActive++;

        uint256 duration = uint256(_numDays) * 1 days;

        stakes[idCounter] = StakeData(msg.sender, "", _amount, shares, duration, block.timestamp);
        stakeOwner[idCounter] = msg.sender;
        idCounter++;
        emit Stake(msg.sender, _numDays, _amount);
    }

    /// @notice Function to unstake MAXX
    function unstake(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        if (msg.sender != tStake.owner) {
            revert NotOwner();
        }
        totalStakesWithdrawn++;
        totalStakesActive--;

        uint256 withdrawableAmount;
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);
        interestToDate = interestToDate - withdrawnAmounts[_stakeId]; // TODO: check if this affects the ensuing math calculations

        if (daysServed < (tStake.duration / 1 days)) { // unstaking early
            // fee assessed
            withdrawableAmount = (tStake.amount + interestToDate) * daysServed / tStake.duration / 1 days;
        } else if (daysServed > (tStake.duration / 1 days) + LATE_DAYS) { // unstaking late
            // fee assessed
            uint256 daysLate = daysServed - (tStake.duration / 1 days) - LATE_DAYS;
            uint64 penaltyPercentage = uint64(PERCENT_FACTOR * daysLate / 365);
            withdrawableAmount = (tStake.amount + interestToDate) * (PERCENT_FACTOR - penaltyPercentage) / PERCENT_FACTOR;
        } else { // unstaking on time
            withdrawableAmount = tStake.amount + interestToDate;
        }

        withdrawnAmounts[_stakeId] = withdrawableAmount;
        uint256 maxxBalance = maxx.balanceOf(address(this));

        if (maxxBalance < withdrawableAmount) {
            maxx.mint(msg.sender, withdrawableAmount - maxxBalance); // mint additional tokens to the user
            require(maxx.transfer(msg.sender, maxxBalance)); // transfer the rest of this contract's tokens to the user
        } else {
            require(maxx.transfer(msg.sender, withdrawableAmount)); // transfer the tokens from this contract to the stake owner
        }
        
        emit Unstake(msg.sender, withdrawableAmount);
    }

    /// @notice Function to change stake to maximum duration without penalties
    /// @param _stakeId The id of the stake to change
    function maxShare(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        if (msg.sender != tStake.owner) {
            revert NotOwner();
        }
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);
        interestToDate = interestToDate - withdrawnAmounts[_stakeId];
        tStake.duration = uint256(MAX_STAKE_DAYS) * 1 days;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;

        tStake.amount += interestToDate;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;
        

        totalShares += tStake.shares;
        stakes[_stakeId] = tStake; // Update the stake in storage
        emit Stake(msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to restake without penalties
    /// @param _stakeId The id of the stake to restake
    /// @param _topUpAmount The amount of MAXX to top up the stake
    function restake(uint256 _stakeId, uint256 _topUpAmount) external {
        StakeData memory tStake = stakes[_stakeId];
        if (msg.sender != tStake.owner) {
            revert NotOwner();
        }
        uint256 maturation = tStake.startDate + tStake.duration;
        if (block.timestamp < maturation) {
            revert StakeNotComplete();
        }
        if (_topUpAmount > maxx.balanceOf(msg.sender)) {
            revert InsufficientMaxx();
        }
        require(maxx.transferFrom(msg.sender, address(this), _topUpAmount)); // transfer tokens to this contract
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);
        interestToDate = interestToDate - withdrawnAmounts[_stakeId];
        tStake.amount += _topUpAmount + interestToDate;
        tStake.startDate = block.timestamp;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;
        totalShares += tStake.shares;
        stakes[_stakeId] = tStake;
        emit Stake(msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to transfer stake ownership
    /// @param _to The new owner of the stake
    /// @param _stakeId The id of the stake
    function transfer(address _to, uint256 _stakeId) external returns (bool) {
        if (msg.sender != stakes[_stakeId].owner) {
            revert NotOwner();
        }
        _transferStake(_stakeId, _to);
        return true;
    }

    /// @notice Function for an external address to transfer stake ownership with an allowance
    /// @dev Only removes the allowance from the calling address, if multiple addresses were given an allowance, they will persist
    /// @param _from The address of the old owner of the stake
    /// @param _to The address to the new owner of the stake
    /// @param _stakeId The id of the stake
    function transferFrom(address _from, address _to, uint256 _stakeId) external returns (bool) {
        if (!allowances[_from][_stakeId][msg.sender]) {
            revert UnauthorizedTransfer();
        }
        allowances[_from][_stakeId][msg.sender] = false; // remove the allowance for the old owner
        _transferStake(_stakeId, _to);
        return true;
    }

    /// @notice Function to withdraw interest early from a stake
    /// @param _stakeId The id of the stake
    function scrapeInterest(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        if (msg.sender != tStake.owner) {
            revert NotOwner();
        }
        uint256 daysServed = (block.timestamp - tStake.startDate) / 1 days;
        uint256 interestToDate = _calcInterestToDate(tStake.shares, daysServed, tStake.duration);

        uint256 durationInDays = tStake.duration / 1 days;

        uint256 percentServed = daysServed * PERCENT_FACTOR / durationInDays; // TODO: confirm early withdrawal math

        uint256 withdrawableAmount = interestToDate * percentServed / PERCENT_FACTOR;
        withdrawnAmounts[_stakeId] = withdrawableAmount;
        require(maxx.transfer(msg.sender, withdrawableAmount));
        emit ScrapeInterest(msg.sender, interestToDate);
    }

    /// @notice This function changes the name of a stake
    /// @param _stakeId The id of the stake
    /// @param _name The new name of the stake
    function changeStakeName(uint256 _stakeId, string memory _name) external {
        StakeData memory tStake = stakes[_stakeId];
        if (msg.sender != tStake.owner) {
            revert NotOwner();
        }

        tStake.name = _name; // update variables in memory
        stakes[_stakeId] = tStake; // push data to storage
        emit StakeNameChange(_stakeId, _name);
    }

    /// @notice Function to stake MAXX from amplifier contract
    /// @dev Must approve MAXX before staking
    /// @param _amount The amount of MAXX to stake
    function amplifierStake(uint16 _numDays, uint256 _amount) external {
        // require (msg.sender == address(liquidityAmplifier), "Can only be called by amplifier contract");
        require(maxx.transferFrom(msg.sender, address(this), _amount)); // transfer tokens to the contract

        uint256 shares = _calcShares(_numDays, _amount);
        if (_numDays >= 365) {
            // TODO: calculate the bonus amount of shares
            // e.g. shares = shares * 10%
        }
        
        totalShares += shares;
        totalStakesAlltime++;
        totalStakesActive++;

        uint256 duration = _numDays * 1 days;

        // Uses tx.origin as the owner of the stake -> owner must be an external account
        stakes[idCounter] = StakeData(tx.origin, "", _amount, shares, duration, block.timestamp);
        idCounter++;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _owner The owner of the stake
    /// @param _amount The amount of MAXX to stake
    function freeClaimStake(address _owner, uint256 _amount) external {
        // require (msg.sender == address(freeClaim), "Can only be called by freeClaim contract");
        require(maxx.transferFrom(msg.sender, address(this), _amount)); // transfer tokens to this contract

        uint256 shares = _calcShares(365, _amount);
        totalShares += shares;
        totalStakesAlltime++;
        totalStakesActive++;

        uint256 duration = 365 days;

        if (block.timestamp < launchDate) {
            stakes[idCounter] = StakeData(_owner, "", _amount, shares, duration, launchDate);
        } else {
            stakes[idCounter] = StakeData(_owner, "", _amount, shares, duration, block.timestamp);
        }
        
        idCounter++;
    }

    /// @notice Funciton to set liquidityAmplifier contract address
    /// @param _liquidityAmplifier The address of the liquidityAmplifier contract
    function setLiquidityAmplifier(address _liquidityAmplifier) external onlyOwner {
        liquidityAmplifier = _liquidityAmplifier;
    }

    /// @notice Function to set freeClaim contract address
    /// @param _freeClaim The address of the freeClaim contract
    function setFreeClaim(address _freeClaim) external onlyOwner {
        freeClaim = _freeClaim;
    }

    /// @notice Function to set the NFT bonus percentage
    /// @param _nftBonusPercentage The percentage of NFT bonus (e.g. 20 = 20%)
    function setNftBonusPercentage(uint8 _nftBonusPercentage) external onlyOwner {
        nftBonusPercentage = _nftBonusPercentage;
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `launchDate`
    function getDaysSinceLaunch() public view returns (uint256 day) {
        day = (block.timestamp - launchDate) / 60 / 60 / 24;
        return day;
    }

    /// @notice This function will change the allowance of _spender to transfer _stakeId
    /// @param _spender The address of the spender
    /// @param _stakeId The id of the stake
    /// @param _approval Whether to allow or disallow _spender to transfer _stakeId
    function approve(address _spender, uint256 _stakeId, bool _approval) public returns (bool) {
        if (msg.sender != stakes[_stakeId].owner) {
            revert NotOwner();
        }
        if (allowances[msg.sender][_stakeId][_spender]) {
            revert AlreadyApproved();
        }
        _approve(msg.sender, _spender, _stakeId, _approval);
        return true;
    }

    /// @notice This function will return if _spender is approved to transfer _stakeId
    /// @param _spender The address of the spender
    /// @param _stakeId The id of the stake
    /// @return bool Whether _spender is approved to transfer _stakeId
    function allowance(address _owner, address _spender, uint256 _stakeId) public view returns (bool) {
        return allowances[_owner][_stakeId][_spender];
    }

    function _approve(address _owner, address _spender, uint256 _stakeId, bool _approval) internal {
        allowances[_owner][_stakeId][_spender] = _approval;
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
        uint256 shareFactor = _getShareFactor();

        uint256 basicShares = _amount / (2 - shareFactor);
        uint256 bpbBonus = _amount / 10000000;
        if (bpbBonus > 10) {
            bpbBonus = 10;
        }
        uint256 bpbShares = basicShares * bpbBonus / 100; // bigger pays better
        uint256 lpbShares = (basicShares + bpbShares) * (duration - 1) / MAGIC_NUMBER; // longer pays better
        shares = basicShares + bpbShares + lpbShares;
        return shares;
    }

    /// @return shareFactor The current share factor
    function _getShareFactor() internal view returns (uint256 shareFactor) {
        shareFactor = 1 - (getDaysSinceLaunch() / 3333);
        assert(shareFactor <= 1);
        return shareFactor;
    }

    /// @dev Calculate interest for a given number of shares and duration
    /// @return interestToDate The interest accrued to date
    function _calcInterestToDate(uint256 _stakeTotalShares, uint256 _daysServed, uint256 _duration) internal pure returns (uint256 interestToDate) {
        uint256 stakeDuration = _duration / 1 days;
        uint256 fullDurationInterest = _stakeTotalShares * BASE_INFLATION * stakeDuration / 365 / BASE_INFLATION_FACTOR;

        // daily interest => (stake_total_shares * (stake_duration/365)) * base_inflation / stake_duration
        // current interest => daily interest * days served

        uint256 currentDurationInterest = _daysServed * _stakeTotalShares * stakeDuration * BASE_INFLATION / stakeDuration  / BASE_INFLATION_FACTOR / 365;

        // uint256 currentDurationInterest = _daysServed * _stakeTotalShares * _daysServed * BASE_INFLATION / stakeDuration  / BASE_INFLATION_FACTOR / stakeDuration;

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