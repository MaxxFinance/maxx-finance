// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface for the Maxx Finance liquidity amplifier contract
interface ILiquidityAmplifier {
    /// Invalid referrer address `referrer`
    /// @param referrer The address of the referrer
    error InvalidReferrer(address referrer);
    /// Liquidity Amplifier has not yet started
    error AmplifierNotStarted();
    ///Liquidity Amplifier is already complete
    error AmplifierComplete();
    /// Liquidity Amplifier is not complete
    error AmplifierNotComplete();
    /// Claim period has ended
    error ClaimExpired();
    /// Invalid input day
    /// @param day The amplifier day 1-60
    error InvalidDay(uint256 day);
    /// User has already claimed for this day
    /// @param day The amplifier day 1-60
    error AlreadyClaimed(uint256 day);
    /// User has already claimed referral rewards
    error AlreadyClaimedReferrals();
    /// The Maxx allocation has already been initialized
    error AlreadyInitialized();
    /// The Maxx Finance Staking contract hasn't been initialized
    error StakingNotInitialized();
    /// Current or proposed launch date has already passed
    error LaunchDatePassed();
    /// Unable to withdraw Matic
    error WithdrawFailed();
    /// MaxxGenesis address not set
    error MaxxGenesisNotSet();
    /// MaxxGenesis NFT not minted
    error MaxxGenesisMintFailed();
    /// Maxx transfer failed
    error MaxxTransferFailed();

    /// @notice Emitted when matic is 'deposited'
    /// @param user The user depositing matic into the liquidity amplifier
    /// @param amount The amount of matic depositied
    /// @param referrer The address of the referrer (0x0 if none)
    event Deposit(
        address indexed user,
        uint256 indexed amount,
        address indexed referrer
    );

    /// @notice Emitted when MAXX is claimed from a deposit
    /// @param user The user claiming MAXX
    /// @param day The day of the amplifier claimed
    /// @param amount The amount of MAXX claimed
    event Claim(
        address indexed user,
        uint256 indexed day,
        uint256 indexed amount
    );

    /// @notice Emitted when MAXX is claimed from a referral
    /// @param user The user claiming MAXX
    /// @param amount The amount of MAXX claimed
    event ClaimReferral(address indexed user, uint256 amount);

    /// @notice Emitted when a deposit is made with a referral
    event Referral(
        address indexed user,
        address indexed referrer,
        uint256 amount
    );
    /// @notice Emitted when the Maxx Stake contract address is set
    event StakeAddressSet(address indexed stake);
    /// @notice Emitted when the Maxx Genesis NFT contract address is set
    event MaxxGenesisSet(address indexed maxxGenesis);
    /// @notice Emitted when the launch date is updated
    event LaunchDateUpdated(uint256 newLaunchDate);
    /// @notice Emitted when a Maxx Genesis NFT is minted
    event MaxxGenesisMinted(address indexed user, string code);

    /// @notice Liquidity amplifier start date
    function launchDate() external view returns (uint256);

    /// @notice This function will return all liquidity amplifier participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipants() external view returns (address[] memory);

    /// @notice This function will return all liquidity amplifier participants for `day` day
    /// @param day The day for which to return the participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipantsByDay(uint256 day)
        external
        view
        returns (address[] memory);

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
