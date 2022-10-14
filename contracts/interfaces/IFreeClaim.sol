// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface for the Maxx Finance Free Claim
interface IFreeClaim {
    function stakeClaim(uint256 unstakedClaimId, uint256 claimId) external;

    function getAllUnstakedClaims() external view returns (uint256[] memory);
}
