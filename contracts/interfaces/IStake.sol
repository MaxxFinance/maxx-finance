// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    enum MaxxNFT {
        MaxxGenesis,
        MaxxBoost
    }

    function stakes(uint256) external view returns (StakeData memory);

    function ownerOf(uint256) external view returns (address);

    function launchDate() external view returns (uint256);

    function isApprovedForAll(address, address) external view returns (bool);

    function stake(uint16 numDays, uint256 amount) external;

    function unstake(uint256 stakeId) external;

    function freeClaimStake(
        address owner,
        uint16 numDays,
        uint256 amount
    ) external returns (uint256 stakeId, uint256 shares);

    function amplifierStake(
        address owner,
        uint16 numDays,
        uint256 amount
    ) external returns (uint256 stakeId, uint256 shares);

    function amplifierStake(
        uint16 numDays,
        uint256 amount,
        uint256 tokenId,
        MaxxNFT nft
    ) external returns (uint256 stakeId, uint256 shares);

    function allowance(
        address owner,
        address spender,
        uint256 stakeId
    ) external view returns (bool);

    function approve(
        address spender,
        uint256 stakeId,
        bool approval
    ) external returns (bool);

    function transfer(address to, uint256 stakeId) external;

    function transferFrom(
        address from,
        address to,
        uint256 stakeId
    ) external;
}
