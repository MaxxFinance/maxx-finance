// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title The interface for the Maxx Finance staking contract
interface IStake is IERC721 {
    /// Not authorized to control the stake
    error NotAuthorized();

    /// Cannot stake less than {MIN_STAKE_DAYS} days
    error StakeTooShort();

    /// Cannot stake more than {MAX_STAKE_DAYS} days
    error StakeTooLong();

    /// Address does not own enough MAXX tokens
    error InsufficientMaxx();

    /// Stake has not yet completed
    error StakeNotComplete();

    /// Stake has already been claimed
    error StakeAlreadyWithdrawn();

    /// User does not own the NFT
    error IncorrectOwner();

    /// NFT boost has already been used
    error UsedNFT();

    /// NFT collection is not accepted
    error NftNotAccepted();

    /// Token transfer returned false (failed)
    error TransferFailed();

    /// Tokens already staked for maximum duration
    error AlreadyMaxDuration();

    /// Unstaked Free Claims have already been migrated
    error FreeClaimsAlreadyMigrated();

    /// Current or proposed launch date has already passed
    error LaunchDatePassed();

    /// `_nft` does not support the IERC721 interface
    /// @param _nft the address of the NFT contract
    error InterfaceNotSupported(address _nft);

    /// @notice Emitted when MAXX is staked
    /// @param stakeId The ID of the stake
    /// @param user The user staking MAXX
    /// @param numDays The number of days staked
    /// @param amount The amount of MAXX staked
    event Stake(
        uint256 indexed stakeId,
        address indexed user,
        uint16 numDays,
        uint256 amount
    );

    /// @notice Emitted when MAXX is unstaked
    /// @param user The user unstaking MAXX
    /// @param amount The amount of MAXX unstaked
    event Unstake(
        uint256 indexed stakeId,
        address indexed user,
        uint256 amount
    );

    /// @notice Emitted when the name of a stake is changed
    /// @param stakeId The id of the stake
    /// @param name The new name of the stake
    event StakeNameChange(uint256 stakeId, string name);

    /// @notice Emitted when the launch date is updated
    event LaunchDateUpdated(uint256 newLaunchDate);
    /// @notice Emitted when the liquidityAmplifier address is updated
    event LiquidityAmplifierSet(address _liquidityAmplifier);
    /// @notice Emitted when the freeClaim address is updated
    event FreeClaimSet(address _freeClaim);
    event NftBonusSet(address _nft, uint256 _bonus);
    event BaseURISet(string _baseUri);
    event AcceptedNftAdded(address _nft);
    event AcceptedNftRemoved(address _nft);

    struct StakeData {
        string name;
        address owner;
        uint256 amount;
        uint256 shares;
        uint256 duration;
        uint256 startDate;
        bool withdrawn;
    }

    enum MaxxNFT {
        MaxxGenesis,
        MaxxBoost
    }

    function stakes(uint256)
        external
        view
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        );

    function launchDate() external view returns (uint256);

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
}
