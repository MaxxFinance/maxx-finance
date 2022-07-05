// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title The interface for the Maxx Finance staking contract
interface IStake {
    function stake(uint16, uint256) external;
    function unstake(uint256) external;
    function freeClaimStake(address, uint256) external;
    function amplifierStake(uint16, uint256) external;
}