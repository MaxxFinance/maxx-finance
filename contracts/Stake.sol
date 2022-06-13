// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
    /// @param numDays The number of days MAXX was staked
    /// @param amount The amount of MAXX unstaked
    event Unstake(address indexed user, uint16 numDays, uint256 amount);

    IERC20 public MAXX;

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _days The number of days to stake (min 5, max 3333)
    function stake(uint16 _days, uint256 _amount) public {
        require(_days >= 5, "Minimum days to stake is 5");
        require(_days <= 3333, "Maximum days to stake is 3333");

        MAXX.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Function to unstake MAXX
    function unstake() public {
        // if (block.timestamp < stakeDate) { // unstaking early
        //     // fee assessed
        // } else if (block.timestamp > stakeDate + lateDays) {
        //     // fee assessed
        // }
    }
}