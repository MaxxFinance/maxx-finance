// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "hardhat/console.sol";

import { IStake } from './interfaces/IStake.sol';

/// @title Maxx Finance Stake Marketplace
/// @author Alta Web3 Labs
contract Marketplace is Ownable {

    /// @notice Emitted when stake is listed to the market
    /// @param user The user who listed the stake
    /// @param stakeId The id of the stake
    /// @param amount The amount asked for the stake
    event List(address indexed user, uint256 indexed stakeId, uint256 amount);

    /// @notice Emitted when stake is purhased off the market
    /// @param user The user who purchased the stake
    /// @param stakeId The id of the stake
    /// @param amount The purchase amount
    event Purchase(address indexed user, uint256 indexed stakeId, uint256 amount);

    IStake public maxxStake;

    /// mapping of stake id to their desired sellPrice
    mapping(uint256 => uint256) public sellPrice;

    mapping(uint256 => bool) public isListed;
    
    // // mapping of stake id to their listing
    // mapping(uint256 => Listing) public listings;
    Listing[] public listings;

    struct Listing {
        address lister;
        uint256 amount;
        uint256 endTime;
    }

    constructor(address _maxxStake) {
        maxxStake = IStake(_maxxStake);
    }

    /// @notice Function to list stake on the market
    /// @param _stakeId The id of the stake to list
    /// @param _amount The price of the stake in the native coin
    function listStake(uint256 _stakeId, uint256 _amount, uint256 _duration) external {
        console.log("enter listStake");
        // require approval
        address stakeOwner = maxxStake.stakeOwner(_stakeId);
        require(stakeOwner == msg.sender, "You are not the owner of this stake");
        sellPrice[_stakeId] = _amount;
        console.log("update sellPrice");
        listings.push(Listing(msg.sender, _amount, block.timestamp + _duration));
        console.log("push listing");
        emit List(msg.sender, _stakeId, _amount);
    }

    /// @notice Function to buy a stake from the market
    /// @param _stakeId The id of the stake to buy
    function buyStake(uint256 _stakeId) external payable {
        IStake.StakeData memory tStake = maxxStake.stakes(_stakeId);
        require(msg.value >= sellPrice[_stakeId], "Must send at least the asking price");
        sellPrice[_stakeId] = 0;
        maxxStake.transferStake(_stakeId, msg.sender);
        payable(tStake.owner).transfer(msg.value);
        emit Purchase(msg.sender, _stakeId, msg.value);
    }

    /// @notice Function to return all listings on the market
    /// @return The array of listings
    function getAllListings() external view returns(Listing[] memory)  {
        return listings;
    }
}