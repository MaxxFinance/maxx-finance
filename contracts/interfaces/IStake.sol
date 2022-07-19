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

    function stake(uint16, uint256) external;
    function unstake(uint256) external;
    function freeClaimStake(address, uint256) external;
    function amplifierStake(uint16, uint256) external;

    function allowance(address, uint256) external view returns (bool);
    function transferStake(uint256 stakeId, address to) external returns (bool);
}