// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {ILiquidityAmplifier} from "./interfaces/ILiquidityAmplifier.sol";
import {IStake} from "./interfaces/IStake.sol";
import {IMaxxFinance} from "./interfaces/IMaxxFinance.sol";
import {IMAXXBoost} from "./interfaces/IMAXXBoost.sol";

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
error AlreadyClaimed(uint8 day);
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

/// @title Maxx Finance Liquidity Amplifier
/// @author Alta Web3 Labs - SonOfMosiah
contract LiquidityAmplifier is ILiquidityAmplifier, Ownable {
    using ERC165Checker for address;

    uint256[] private _maxxDailyAllocation = new uint256[](AMPLIFIER_PERIOD);
    uint256[] private _effectiveMaticDailyDeposits =
        new uint256[](AMPLIFIER_PERIOD);
    uint256[] private _maticDailyDeposits = new uint256[](AMPLIFIER_PERIOD);

    /// @notice Maxx Finance Vault address
    address public maxxVault;

    /// @notice maxxGenesis NFT
    address public maxxGenesis;

    /// @notice Array of addresses that have participated in the liquidity amplifier
    address[] public participants;

    /// @notice Array of address that participated in the liquidity amplifier for each day
    mapping(uint8 => address[]) public participantsByDay;

    /// @inheritdoc ILiquidityAmplifier
    uint256 public launchDate;

    /// @notice Address of the Maxx Finance staking contract
    IStake public stake;

    /// @notice Maxx Finance token
    address public maxx;

    bool private _allocationInitialized;
    bool public initialized;

    uint16 public constant MAX_LATE_DAYS = 60;
    uint16 public constant CLAIM_PERIOD = 60;
    uint16 public constant AMPLIFIER_PERIOD = 60;
    uint256 public constant MIN_GENESIS_AMOUNT = 5e19; // 50 matic

    /// @notice maps address to day (indexed at 0) to amount of tokens deposited
    mapping(address => uint256[60]) public userDailyDeposits;
    /// @notice maps address to day (indexed at 0) to amount of effective tokens deposited adjusted for referral and nft bonuses
    mapping(address => uint256[60]) public effectiveUserDailyDeposits;
    /// @notice maps address to day (indexed at 0) to amount of effective tokens gained by referring users
    mapping(address => uint256[60]) public effectiveUserReferrals;
    /// @notice tracks if address has participated in the amplifier
    mapping(address => bool) public participated;
    /// @notice tracks if address has claimed for a given day
    mapping(address => mapping(uint8 => bool)) public participatedByDay;
    mapping(address => mapping(uint256 => bool)) public dayClaimed;
    mapping(address => bool) public claimedReferrals;

    mapping(address => uint256[]) public userAmpReferral;

    /// @notice
    uint256[60] public dailyDepositors;

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
        uint8 indexed day,
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

    constructor() {
        _transferOwnership(tx.origin);
    }

    /// @notice Initialize maxxVault, launchDate and MAXX token address
    /// @dev Function can only be called once
    /// @param _maxxVault The address of the Maxx Finance Vault
    /// @param _launchDate The launch date of the liquidity amplifier
    /// @param _maxx The address of the MAXX token
    function init(
        address _maxxVault,
        uint256 _launchDate,
        address _maxx
    ) external onlyOwner {
        if (initialized) {
            revert AlreadyInitialized();
        }
        maxxVault = _maxxVault;
        launchDate = _launchDate;
        maxx = _maxx;
        initialized = true;
    }

    /// @dev Function to deposit matic to the contract
    function deposit() external payable {
        if (block.timestamp >= launchDate + (AMPLIFIER_PERIOD * 1 days)) {
            revert AmplifierComplete();
        }

        uint256 amount = msg.value;
        uint8 day = getDay();

        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }

        if (!participatedByDay[msg.sender][day]) {
            participatedByDay[msg.sender][day] = true;
            participantsByDay[day].push(msg.sender);
        }

        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += amount;

        dailyDepositors[day] += 1;
        emit Deposit(msg.sender, amount, address(0));
    }

    /// @dev Function to deposit matic to the contract
    function deposit(address _referrer) external payable {
        if (_referrer == address(0) || _referrer == msg.sender) {
            revert InvalidReferrer(_referrer);
        }
        if (block.timestamp >= launchDate + (AMPLIFIER_PERIOD * 1 days)) {
            revert AmplifierComplete();
        }
        uint256 amount = msg.value;
        uint256 originalAmount = amount;
        uint256 referralBonus = amount / 10; // +10% referral bonus
        amount += referralBonus;
        uint256 referrerAmount = msg.value / 20; // 5% bonus for referrer
        uint256 effectiveDeposit = amount + referrerAmount;
        uint8 day = getDay();
        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }
        if (!participatedByDay[msg.sender][day]) {
            participatedByDay[msg.sender][day] = true;
            participantsByDay[day].push(msg.sender);
        }
        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        effectiveUserReferrals[_referrer][day] += referrerAmount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += effectiveDeposit;
        dailyDepositors[day] += 1;

        userAmpReferral[_referrer].push(block.timestamp);
        userAmpReferral[_referrer].push(amount);
        userAmpReferral[_referrer].push(referrerAmount);

        emit Referral(msg.sender, _referrer, originalAmount);
        emit Deposit(msg.sender, originalAmount, _referrer);
    }

    /// @dev Function to deposit matic to the contract
    function deposit(string memory _code) external payable {
        if (block.timestamp >= launchDate + (AMPLIFIER_PERIOD * 1 days)) {
            revert AmplifierComplete();
        }

        uint256 amount = msg.value;
        if (amount >= MIN_GENESIS_AMOUNT) {
            _mintMaxxGenesis(_code);
        }

        uint8 day = getDay();

        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }

        if (!participatedByDay[msg.sender][day]) {
            participatedByDay[msg.sender][day] = true;
            participantsByDay[day].push(msg.sender);
        }

        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += amount;

        dailyDepositors[day] += 1;
        emit Deposit(msg.sender, amount, address(0));
    }

    /// @dev Function to deposit matic to the contract
    function deposit(string memory _code, address _referrer) external payable {
        if (_referrer == address(0) || _referrer == msg.sender) {
            revert InvalidReferrer(_referrer);
        }

        if (block.timestamp >= launchDate + (AMPLIFIER_PERIOD * 1 days)) {
            revert AmplifierComplete();
        }

        uint256 amount = msg.value;
        uint256 originalAmount = amount;
        if (amount >= MIN_GENESIS_AMOUNT) {
            _mintMaxxGenesis(_code);
        }

        uint256 referralBonus = amount / 10; // +10% referral bonus
        amount += referralBonus;
        uint256 referrerAmount = msg.value / 20; // 5% bonus for referrer
        uint256 effectiveDeposit = amount + referrerAmount;
        uint8 day = getDay();
        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }

        if (!participatedByDay[msg.sender][day]) {
            participatedByDay[msg.sender][day] = true;
            participantsByDay[day].push(msg.sender);
        }
        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        effectiveUserReferrals[_referrer][day] += referrerAmount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += effectiveDeposit;
        dailyDepositors[day] += 1;

        userAmpReferral[_referrer].push(block.timestamp);
        userAmpReferral[_referrer].push(amount);
        userAmpReferral[_referrer].push(referrerAmount);

        emit Referral(msg.sender, _referrer, originalAmount);
        emit Deposit(msg.sender, originalAmount, _referrer);
    }

    /// @notice Function to claim MAXX directly to user wallet
    /// @param _day The day to claim MAXX for
    function claim(uint8 _day) external {
        _checkDayRange(_day);
        if (
            address(stake) == address(0) || block.timestamp < stake.launchDate()
        ) {
            revert StakingNotInitialized();
        }

        uint256 amount = _getClaimAmount(_day);

        if (block.timestamp > stake.launchDate() + (CLAIM_PERIOD * 1 days)) {
            // assess late penalty
            uint256 daysLate = block.timestamp -
                (stake.launchDate() + (CLAIM_PERIOD * 1 days));
            if (daysLate >= MAX_LATE_DAYS) {
                revert ClaimExpired();
            } else {
                uint256 penaltyAmount = (amount * daysLate) / MAX_LATE_DAYS;
                amount -= penaltyAmount;
            }
        }

        bool success = IMaxxFinance(maxx).transfer(msg.sender, amount);
        if (!success) {
            revert MaxxTransferFailed();
        }

        emit Claim(msg.sender, _day, amount);
    }

    /// @notice Function to claim MAXX and directly stake
    /// @param _day The day to claim MAXX for
    /// @param _daysToStake The number of days to stake
    function claimToStake(uint8 _day, uint16 _daysToStake) external {
        _checkDayRange(_day);

        uint256 amount = _getClaimAmount(_day);
        IMaxxFinance(maxx).approve(address(stake), amount);
        stake.amplifierStake(msg.sender, _daysToStake, amount);
        emit Claim(msg.sender, _day, amount);
    }

    /// @notice Function to claim referral amount as liquid MAXX tokens
    function claimReferrals() external {
        uint256 amount = _getReferralAmountAndTransfer();
        emit ClaimReferral(msg.sender, amount);
    }

    /// @notice Function to set the Maxx Finance staking contract address
    /// @param _stake Address of the Maxx Finance staking contract
    function setStakeAddress(address _stake) external onlyOwner {
        stake = IStake(_stake);
        emit StakeAddressSet(_stake);
    }

    /// @notice Function to set the Maxx Genesis NFT contract address
    /// @param _maxxGenesis Address of the Maxx Genesis NFT contract
    function setMaxxGenesis(address _maxxGenesis) external onlyOwner {
        maxxGenesis = _maxxGenesis;
        emit MaxxGenesisSet(_maxxGenesis);
    }

    /// @notice Function to initialize the daily allocations
    /// @dev Function can only be called once
    /// @param _dailyAllocation Array of daily MAXX token allocations for 60 days
    function setDailyAllocations(uint256[60] memory _dailyAllocation)
        external
        onlyOwner
    {
        if (_allocationInitialized) {
            revert AlreadyInitialized();
        }
        _maxxDailyAllocation = _dailyAllocation;
        _allocationInitialized = true;
    }

    /// @notice Function to change the daily maxx allocation
    /// @dev Cannot change the daily allocation after the day has passed
    /// @param _day Day of the amplifier to change the allocation for
    /// @param _maxxAmount Amount of MAXX tokens to allocate for the day
    function changeDailyAllocation(uint256 _day, uint256 _maxxAmount)
        external
        onlyOwner
    {
        if (block.timestamp >= launchDate + (_day * 1 days)) {
            revert InvalidDay(_day);
        }
        _maxxDailyAllocation[_day] = _maxxAmount; // indexed at 0
    }

    /// @notice Function to change the start date
    /// @dev Cannot change the start date after the day has passed
    /// @param _launchDate New start date for the liquidity amplifier
    function changeLaunchDate(uint256 _launchDate) external onlyOwner {
        if (block.timestamp >= launchDate || block.timestamp >= _launchDate) {
            revert LaunchDatePassed();
        }
        launchDate = _launchDate;
        emit LaunchDateUpdated(_launchDate);
    }

    /// @notice Function to transfer Matic from this contract to address from input
    /// @param _to address of transfer recipient
    /// @param _amount amount of Matic to be transferred
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    /// @notice Function to reclaim any unallocated MAXX back to the vault
    function withdrawMaxx() external onlyOwner {
        if (address(stake) == address(0)) {
            revert StakingNotInitialized();
        }
        if (
            block.timestamp <=
            stake.launchDate() +
                (CLAIM_PERIOD * 1 days) +
                (MAX_LATE_DAYS * 1 days)
        ) {
            revert AmplifierNotComplete();
        }
        uint256 extraMaxx = IMaxxFinance(maxx).balanceOf(address(this));
        bool success = IMaxxFinance(maxx).transfer(maxxVault, extraMaxx);
        if (!success) {
            revert MaxxTransferFailed();
        }
    }

    /// @notice This function will return all liquidity amplifier participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /// @notice This function will return all liquidity amplifier participants for `day` day
    /// @param day The day for which to return the participants
    /// @return participants Array of addresses that have participated in the Liquidity Amplifier
    function getParticipantsByDay(uint8 day)
        external
        view
        returns (address[] memory)
    {
        return participantsByDay[day];
    }

    /// @notice This function will return a slice of the participants array
    /// @dev This function is used to paginate the participants array
    /// @param start The starting index of the slice
    /// @param length The amount of participants to return
    /// @return participantsSlice Array slice of addresses that have participated in the Liquidity Amplifier
    /// @return newStart The new starting index for the next slice
    function getParticipantsSlice(uint256 start, uint256 length)
        external
        view
        returns (address[] memory participantsSlice, uint256 newStart)
    {
        for (uint256 i = 0; i < length; i++) {
            participantsSlice[i] = (participants[i + start]);
        }
        return (participantsSlice, start + length);
    }

    /// @notice This function will return the maxx allocated for day `day`
    /// @dev This function will revert until after the day `day` has ended
    /// @param _day The day of the liquidity amplifier period 0-59
    /// @return The maxx allocated for day `day`
    function getMaxxDailyAllocation(uint8 _day)
        external
        view
        returns (uint256)
    {
        uint8 currentDay = getDay();

        // changed: does not revert on current day
        if (_day >= AMPLIFIER_PERIOD || _day > currentDay) {
            revert InvalidDay(_day);
        }

        return _maxxDailyAllocation[_day];
    }

    /// @notice This function will return the matic deposited for day `day`
    /// @dev This function will revert until after the day `day` has ended
    /// @param _day The day of the liquidity amplifier period 0-59
    /// @return The matic deposited for day `day`
    function getMaticDailyDeposit(uint8 _day) external view returns (uint256) {
        uint8 currentDay = getDay();

        // changed: does not revert on current day
        if (_day >= AMPLIFIER_PERIOD || _day > currentDay) {
            revert InvalidDay(_day);
        }

        return _maticDailyDeposits[_day];
    }

    /// @notice This function will return the effective matic deposited for day `day`
    /// @dev This function will revert until after the day `day` has ended
    /// @param _day The day of the liquidity amplifier period 0-59
    /// @return The effective matic deposited for day `day`
    function getEffectiveMaticDailyDeposit(uint8 _day)
        external
        view
        returns (uint256)
    {
        uint8 currentDay = getDay();
        if (_day >= AMPLIFIER_PERIOD || _day > currentDay) {
            revert InvalidDay(_day);
        }
        return _effectiveMaticDailyDeposits[_day];
    }

    function getUserAmpReferrals(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userAmpReferral[_user];
    }

    /// @notice This function will return day `day` out of 60 days
    /// @return day How many days have passed since `launchDate`
    function getDay() public view returns (uint8 day) {
        if (block.timestamp < launchDate) {
            revert AmplifierNotStarted();
        }
        day = uint8((block.timestamp - launchDate) / 60 / 60 / 24); // divide by 60 seconds, 60 minutes, 24 hours
        return day;
    }

    function _mintMaxxGenesis(string memory code) internal {
        if (maxxGenesis == address(0)) {
            revert MaxxGenesisNotSet();
        }

        bool success = IMAXXBoost(maxxGenesis).mint(code, msg.sender);
        if (!success) {
            revert MaxxGenesisMintFailed();
        }
        emit MaxxGenesisMinted(msg.sender, code);
    }

    /// @return amount The amount of MAXX tokens to be claimed
    function _getClaimAmount(uint8 _day) internal returns (uint256) {
        if (dayClaimed[msg.sender][_day]) {
            revert AlreadyClaimed(_day);
        }
        dayClaimed[msg.sender][_day] = true;
        uint256 amount = (_maxxDailyAllocation[_day] *
            effectiveUserDailyDeposits[msg.sender][_day]) /
            _effectiveMaticDailyDeposits[_day];
        return amount;
    }

    /// @return amount The amount of MAXX tokens to be claimed
    function _getReferralAmountAndTransfer() internal returns (uint256) {
        if (claimedReferrals[msg.sender]) {
            revert AlreadyClaimedReferrals();
        }
        claimedReferrals[msg.sender] = true;
        uint256 amount;
        for (uint256 i = 0; i < AMPLIFIER_PERIOD; i++) {
            if (_effectiveMaticDailyDeposits[i] > 0) {
                amount +=
                    (_maxxDailyAllocation[i] *
                        effectiveUserDailyDeposits[msg.sender][i]) /
                    _effectiveMaticDailyDeposits[i];
            }
        }
        IMaxxFinance(maxx).transfer(msg.sender, amount);
        return amount;
    }

    function _checkDayRange(uint8 _day) internal view {
        if (_day >= AMPLIFIER_PERIOD) {
            revert InvalidDay(_day);
        }
        if (block.timestamp <= launchDate + CLAIM_PERIOD * 1 days) {
            revert AmplifierNotComplete();
        }
    }
}
