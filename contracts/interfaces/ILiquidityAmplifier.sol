// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface for the Maxx Finance staking contract
interface ILiquidityAmplifier {
    /// @notice Liquidity amplifier start date
    function launchDate() external view returns (uint256);

    /// @notice This function will return all liquidity amplifier participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipants() external view returns (address[] memory);

    /// @notice This function will return a slice of the participants array
    /// @dev This function is used to paginate the participants array
    /// @param start The starting index of the slice
    /// @param length The amount of participants to return
    /// @return participantsSlice Array slice of addresses that have participated in the Liquidity Amplifier
    /// @return newStart The new starting index for the next slice
    function getParticipantsSlice(uint256 start, uint256 length)
        external
        view
        returns (address[] memory participantsSlice, uint256 newStart);
}
