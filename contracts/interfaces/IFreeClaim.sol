// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface for the Maxx Finance Free Claim
interface IFreeClaim {
    /// User has already claimed their allotment of MAXX
    error AlreadyClaimed();

    /// Merkle proof is invalid
    error InvalidProof();

    /// Maxx cannot be the zero address
    error InvalidMaxxAddress();

    /// Merkle root cannot be zero
    error InvalidMerkleRoot();

    /// No more MAXX left to claim
    error FreeClaimEnded();

    /// Free Claim has not started yet
    error FreeClaimNotStarted();

    /// Free Claim has not ended yet
    error FreeClaimNotEnded();

    /// MAXX withdrawal failed
    error MaxxWithdrawFailed();

    /// User cannot refer themselves
    error SelfReferral();

    /// The Maxx Finance Staking contract hasn't been initialized
    error StakingNotInitialized();

    /// Only the Staking contract can call this function
    error OnlyMaxxStake();

    /// MAXX tokens not transferred to this contract
    error MaxxAllocationFailed();

    /// Launch date must be in the future
    error LaunchDateUpdateFailed();

    /// @notice Emitted when free claim is claimed
    /// @param user The user claiming free claim
    /// @param amount The amount of free claim claimed
    event UserClaim(address indexed user, uint256 amount);

    /// @notice Emitted when a referral is made
    /// @param referrer The address of the referrer
    /// @param user The user claiming free claim
    /// @param amount The amount of free claim claimed
    event Referral(
        address indexed referrer,
        address indexed user,
        uint256 amount
    );

    /// @notice Emitted when the maxx token address is set
    /// @param maxx The address of the maxx token
    event MaxxSet(address indexed maxx);

    /// @notice Emitted when the merkle root is set
    /// @param merkleRoot The merkle root
    event MerkleRootSet(bytes32 indexed merkleRoot);

    /// @notice Emitted when the launch date is updated
    /// @param launchDate The new launch date
    event LaunchDateUpdated(uint256 indexed launchDate);

    function stakeClaim(uint256 unstakedClaimId, uint256 claimId) external;

    function getAllUnstakedClaims() external view returns (uint256[] memory);

    function getUnstakedClaimsSlice(uint256 start, uint256 end)
        external
        view
        returns (uint256[] memory);
}
