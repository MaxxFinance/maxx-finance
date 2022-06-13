// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { MaxxStake as Stake } from './Stake.sol';

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
    mapping (address => mapping (uint8 => uint256)) public dailyDeposits;
    uint256[60] private maxxDailyAllocation;
    uint256[60] private ftmDailyDeposits;
    uint256 public startDate;

    /// @notice Address of the MAXX staking contract
    Stake public stake;
    IERC20 public MAXX;

    bool private allocationInitialized = false;

    constructor(uint256 _startDate, address _stake, address _MAXX) {
        startDate = _startDate;
        stake = Stake(_stake);
        MAXX = IERC20(_MAXX);
    }
 
    /// @dev Function to deposit FTM to the contract
    function deposit() external payable {
        require(block.timestamp < startDate +  60 days, "Liquidity Amplifier is completed");
        uint256 amount = msg.value;
        uint8 day = getDay();
        dailyDeposits[msg.sender][day] += amount;
        ftmDailyDeposits[day] += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @dev Function to claim MAXX directly to user wallet
    function claim() external {
        require(block.timestamp > startDate +  60 days, "Amplifier not complete"); // TODO: check if tokens are available the day after or after the 60 days;
        // TODO: add code to get MAXX token amount from deposits

        uint256 amount;
        emit Claim(msg.sender, amount);
    }

    /// @dev Function to claim MAXX and directly stake
    function claimToStake() external {
        require(block.timestamp > startDate +  60 days, "Amplifier not complete"); // TODO: check if tokens are available the day after or after the 60 days;
        // TODO: add code to get MAXX token amount from deposits



        uint256 amount;
        emit Claim(msg.sender, amount);
    }

    /// @notice Function to transfer Fantom from this contract to address from input
    /// @param _to address of transfer recipient
    /// @param _amount amount of Fantom to be transferred
    function withdraw(address payable _to, uint256 _amount) public onlyOwner {
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

    
    function _transfer(address payable _to, uint256 _amount) internal {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `startDate`
    function getDay() public view returns (uint8 day) {
        day = uint8(block.timestamp - startDate / 60 / 60 / 24);
        return day;
    }

    /// @notice Function to initialize the daily allocations
    /// @dev Function can only be called once
    /// @param _maxxDailyAllocation Array of daily MAXX token allocations for 60 days
    function setDailyAllocations(uint256[60] memory _maxxDailyAllocation) public {
        require(!allocationInitialized, "Allocations already initialized");
        maxxDailyAllocation = _maxxDailyAllocation;
        allocationInitialized = true;
    }

    /// @param _day Day of the amplifier to change the allocation for
    /// @param _maxxAmount Amount of MAXX tokens to allocate for the day
    function changeDailyAllocation(uint256 _day, uint256 _maxxAmount) external {
        require(block.timestamp < startDate + (_day * 1 days), "Day already passed");
        maxxDailyAllocation[_day - 1] = _maxxAmount; // index 0 is day 1
    }
}