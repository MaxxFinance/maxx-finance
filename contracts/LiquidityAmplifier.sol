// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { IStake } from "./interfaces/IStake.sol";

/// @author Alta Web3 Labs
contract LiquidityAmplifier is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when fantom is 'deposited'
    /// @param user The user depositing fantom into the liquidity amplifier
    /// @param amount The amount of fantom depositied
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when MAXX is claimed
    /// @param user The user claiming MAXX
    /// @param amount The amount of MAXX claimed
    event Claim(address indexed user, uint256 amount);

    /// maps address to day (indexed at 0) to amount of tokens deposited
    mapping (address => uint256[60]) public userDailyDeposits;
    uint256[60] private maxxDailyAllocation;
    uint256[60] private ftmDailyDeposits;

    mapping (address => bool) public participated;
    address[] public participants;

    /// @notice Liquidity amplifier start date
    uint256 public startDate;

    /// @notice Address of the Maxx Finance staking contract
    IStake public stake;

    /// @notice Address of the MAXX token contract
    IERC20 public MAXX;

    bool private allocationInitialized = false;

    constructor(uint256 _startDate, address _stake, address _MAXX) {
        startDate = _startDate;
        stake = IStake(_stake);
        MAXX = IERC20(_MAXX);
    }
 
    /// @dev Function to deposit FTM to the contract
    function deposit() external payable {
        require(block.timestamp < startDate +  60 days, "Liquidity Amplifier is completed");
        uint256 amount = msg.value;
        uint8 day = getDay();
        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }
        userDailyDeposits[msg.sender][day] += amount;
        ftmDailyDeposits[day] += amount;
        emit Deposit(msg.sender, amount);
    }

    // TODO: should there be a way to claim partial amounts of MAXX?

    /// @dev Function to claim MAXX directly to user wallet
    function claim() external {
        require(block.timestamp > startDate +  60 days, "Amplifier not complete"); // TODO: check if tokens are available the day after or after the 60 days;
        uint256 amount = _getClaimAmount();
        MAXX.safeTransfer(msg.sender, amount);
        emit Claim(msg.sender, amount);
    }

    /// @dev Function to claim MAXX and directly stake
    function claimToStake(uint16 _daysToStake) external {
        require(block.timestamp > startDate +  60 days, "Amplifier not complete"); // TODO: check if tokens are available the day after or after the 60 days;
        uint256 amount = _getClaimAmount();
        MAXX.safeApprove(address(stake), amount);
        stake.amplifierStake(_daysToStake, amount);
        emit Claim(msg.sender, amount);
    }

    /// @param _day Day of the amplifier to change the allocation for
    /// @param _maxxAmount Amount of MAXX tokens to allocate for the day
    function changeDailyAllocation(uint256 _day, uint256 _maxxAmount) external {
        require(block.timestamp < startDate + (_day * 1 days), "Day already passed");
        maxxDailyAllocation[_day - 1] = _maxxAmount; // index 0 is day 1
    }

    /// @notice Function to initialize the daily allocations
    /// @dev Function can only be called once
    /// @param _maxxDailyAllocation Array of daily MAXX token allocations for 60 days
    function setDailyAllocations(uint256[60] memory _maxxDailyAllocation) external {
        require(!allocationInitialized, "Allocations already initialized");
        maxxDailyAllocation = _maxxDailyAllocation;
        allocationInitialized = true;
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `startDate`
    function getDay() public view returns (uint8 day) {
        day = uint8(block.timestamp - startDate / 60 / 60 / 24);
        return day;
    }

    /// @notice This function will return all liquidity amplifier participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /// @notice Function to transfer Fantom from this contract to address from input
    /// @param _to address of transfer recipient
    /// @param _amount amount of Fantom to be transferred
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
         // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    /// @notice Function to reclaim any unallocated MAXX after 60 days
    /// @param _to address of transfer recipient
    function withdrawUnallocatedMaxx(address _to) external onlyOwner {
        require(block.timestamp > startDate + 60 days, "Amplifier not complete");
        uint256 allocatedMaxx;
        for (uint8 i = 0; i < 60; i++) {
            allocatedMaxx += maxxDailyAllocation[i];
        }
        uint256 unallocatedMaxx = MAXX.balanceOf(address(this)) - allocatedMaxx;
        MAXX.safeTransfer(_to, unallocatedMaxx);
    }

    /// @return amount The amount of MAXX tokens to be claimed
    function _getClaimAmount() view internal returns(uint256 amount) {
        for (uint8 i = 0; i < 60; i++) {
            amount += maxxDailyAllocation[i] * userDailyDeposits[msg.sender][i] / ftmDailyDeposits[i];
        }
    }

    function _transfer(address payable _to, uint256 _amount) internal { 
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }
}