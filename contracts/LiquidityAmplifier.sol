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

    /// @inheritdoc ILiquidityAmplifier
    uint256 public launchDate;

    /// @notice Address of the Maxx Finance staking contract
    IStake public stake;

    /// @notice Maxx Finance token
    address public maxx;

    bool private _allocationInitialized;

    uint16 public constant MAX_LATE_DAYS = 100;
    uint16 public constant CLAIM_PERIOD = 60;
    uint16 public constant AMPLIFIER_PERIOD = 60;
    uint256 public constant MIN_GENESIS_AMOUNT = 1e24; //1 million MAXX // QUESTION: Is this the right amount?

    /// @notice maps address to day (indexed at 0) to amount of tokens deposited
    mapping(address => uint256[60]) public userDailyDeposits;
    /// @notice maps address to day (indexed at 0) to amount of effective tokens deposited adjusted for referral and nft bonuses
    mapping(address => uint256[60]) public effectiveUserDailyDeposits;
    /// @notice maps address to day (indexed at 0) to amount of effective tokens gained by referring users
    mapping(address => uint256[60]) public effectiveUserReferrals;
    /// @notice tracks if address has participated in the amplifier
    mapping(address => bool) public participated;

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

    /// @notice Emitted when MAXX is claimed
    /// @param user The user claiming MAXX
    /// @param amount The amount of MAXX claimed
    event Claim(address indexed user, uint256 amount);

    // TODO add more events

    constructor(
        address _maxxVault,
        uint256 _launchDate,
        address _maxx
    ) {
        maxxVault = _maxxVault;
        launchDate = _launchDate;
        maxx = _maxx;
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
        if (block.timestamp >= launchDate + AMPLIFIER_PERIOD * 1 days) {
            revert AmplifierComplete();
        }
        uint256 amount = msg.value;
        uint256 referralBonus = amount / 10; // +10% referral bonus
        amount += referralBonus;
        uint256 referrerAmount = msg.value / 20; // 5% bonus for referrer
        uint256 effectiveDeposit = amount + referrerAmount;
        uint8 day = getDay();
        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }
        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        effectiveUserReferrals[_referrer][day] += referrerAmount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += effectiveDeposit;
        dailyDepositors[day] += 1;

        userAmpReferral[msg.sender].push(block.timestamp);
        userAmpReferral[msg.sender].push(amount);
        userAmpReferral[msg.sender].push(referrerAmount);

        emit Deposit(msg.sender, amount, _referrer);
    }

    /// @dev Function to deposit matic to the contract
    function deposit(string memory _code) external payable {
        if (block.timestamp >= launchDate + (AMPLIFIER_PERIOD * 1 days)) {
            revert AmplifierComplete();
        }

        uint256 amount = msg.value;
        if (amount >= MIN_GENESIS_AMOUNT) {
            _mintMaxxGenesis(_code); // QUESTION: should revert if amount is less than MIN_GENESIS_AMOUNT?
        }

        uint8 day = getDay();

        if (!participated[msg.sender]) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
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
        if (block.timestamp >= launchDate + AMPLIFIER_PERIOD * 1 days) {
            revert AmplifierComplete();
        }
        uint256 amount = msg.value;

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
        userDailyDeposits[msg.sender][day] += amount;
        effectiveUserDailyDeposits[msg.sender][day] += amount;
        effectiveUserReferrals[_referrer][day] += referrerAmount;
        _maticDailyDeposits[day] += amount;
        _effectiveMaticDailyDeposits[day] += effectiveDeposit;
        dailyDepositors[day] += 1;

        userAmpReferral[msg.sender].push(block.timestamp);
        userAmpReferral[msg.sender].push(amount);
        userAmpReferral[msg.sender].push(referrerAmount);

        emit Deposit(msg.sender, amount, _referrer);
    }

    /// @notice Function to claim MAXX directly to user wallet
    function claim() external {
        if (block.timestamp <= launchDate + AMPLIFIER_PERIOD * 1 days) {
            revert AmplifierNotComplete();
        }
        if (
            address(stake) == address(0) || block.timestamp < stake.launchDate()
        ) {
            revert StakingNotInitialized();
        }

        uint256 amount = _getClaimAmount();

        if (block.timestamp > stake.launchDate() + CLAIM_PERIOD * 1 days) {
            // assess late penalty
            uint256 daysLate = block.timestamp -
                (stake.launchDate() + CLAIM_PERIOD * 1 days);
            if (daysLate >= MAX_LATE_DAYS) {
                revert ClaimExpired();
            } else {
                uint256 penaltyAmount = (amount * daysLate) / MAX_LATE_DAYS;
                amount -= penaltyAmount;
            }
        }

        IMaxxFinance(maxx).transfer(msg.sender, amount);
        emit Claim(msg.sender, amount);
    }

    /// @notice Function to claim MAXX and directly stake
    function claimToStake(uint16 _daysToStake) external {
        if (block.timestamp <= launchDate + CLAIM_PERIOD * 1 days) {
            revert AmplifierNotComplete();
        }
        uint256 amount = _getClaimAmount();
        IMaxxFinance(maxx).approve(address(stake), amount);
        stake.amplifierStake(_daysToStake, amount);
        emit Claim(msg.sender, amount);
    }

    /// @notice Function to claim MAXX and directly stake
    /// @param _daysToStake The number of days to stake
    /// @param _tokenId The token id of the NFT to use for a staking boost
    /// @param _maxxNFT The NFT collection (0 - MaxxGenesis, 1 - MaxxBoost)
    function claimToStake(
        uint16 _daysToStake,
        uint256 _tokenId,
        IStake.MaxxNFT _maxxNFT
    ) external {
        if (block.timestamp <= launchDate + CLAIM_PERIOD * 1 days) {
            revert AmplifierNotComplete();
        }
        uint256 amount = _getClaimAmount();
        IMaxxFinance(maxx).approve(address(stake), amount);
        stake.amplifierStake(_daysToStake, amount, _tokenId, _maxxNFT);
        emit Claim(msg.sender, amount);
    }

    /// @notice Function to claim referral amount and directly stake
    function claimReferrals() external {
        if (block.timestamp <= launchDate + CLAIM_PERIOD * 1 days) {
            revert AmplifierNotComplete();
        }
        uint256 amount = _getReferralAmount();
        IMaxxFinance(maxx).approve(address(stake), amount);
        stake.amplifierStake(14, amount);
        emit Claim(msg.sender, amount);
    }

    /// @notice Function to set the Maxx Finance staking contract address
    /// @param _stake Address of the Maxx Finance staking contract
    function setStakeAddress(address _stake) external onlyOwner {
        stake = IStake(_stake);
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
        IMaxxFinance(maxx).transfer(maxxVault, extraMaxx);
    }

    /// @inheritdoc ILiquidityAmplifier
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /// @inheritdoc ILiquidityAmplifier
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
        if (_day >= AMPLIFIER_PERIOD || _day >= currentDay) {
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
    }

    /// @return amount The amount of MAXX tokens to be claimed
    function _getClaimAmount() internal view returns (uint256 amount) {
        for (uint8 i = 0; i < 60; i++) {
            amount +=
                (_maxxDailyAllocation[i] *
                    effectiveUserDailyDeposits[msg.sender][i]) /
                _effectiveMaticDailyDeposits[i];
        }
    }

    /// @return amount The amount of MAXX tokens to be claimed
    function _getReferralAmount() internal view returns (uint256 amount) {
        for (uint8 i = 0; i < 60; i++) {
            amount +=
                (_maxxDailyAllocation[i] *
                    effectiveUserReferrals[msg.sender][i]) /
                _effectiveMaticDailyDeposits[i];
        }
    }
}
