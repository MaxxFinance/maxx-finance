// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title The interface for the Maxx Finance staking contract
interface IStake {

    struct StakeData {
        address owner;
        string name; // 32 letters max
        uint256 amount;
        uint256 shares;
        uint256 duration;
        uint256 startDate;
    }

    function stakes(uint256) external view returns (StakeData memory);
    function stakeOwner(uint256) external view returns (address);

    function stake(uint16 numDays, uint256 amount) external;
    function unstake(uint256 stakeId) external;
    function freeClaimStake(address owner, uint256 amount) external;
    function amplifierStake(uint16 numDays, uint256 amount) external;

    function allowance(address owner, address spender, uint256 stakeId) external view returns (bool);
    function approve(address spender, uint256 stakeId, bool approval) external returns (bool);
    function transfer(address to, uint256 stakeId) external returns (bool);
    function transferFrom(address from, address to, uint256 stakeId) external returns (bool);
}