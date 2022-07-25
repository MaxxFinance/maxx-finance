// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title The interface for the Maxx Finance staking contract
interface ILiquidityAmplifier {
    function launchDate() external view returns (uint256);
}
