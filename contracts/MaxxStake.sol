// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ILiquidityAmplifier} from "./interfaces/ILiquidityAmplifier.sol";
import {IMaxxFinance} from "./interfaces/IMaxxFinance.sol";
import {IMAXXBoost} from "./interfaces/IMAXXBoost.sol";

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

/// Current or proposed launch date has already passed
error LaunchDatePassed();

/// `_nft` does not support the IERC721 interface
/// @param _nft the address of the NFT contract
error InterfaceNotSupported(address _nft);

/// @title Maxx Finance staking contract
/// @author Alta Web3 Labs - SonOfMosiah
contract MaxxStake is
    ERC721,
    ERC721Enumerable,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using ERC165Checker for address;
    using Counters for Counters.Counter;

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

    mapping(address => bool) public isAcceptedNft;
    /// @dev 10 = 10% boost
    mapping(address => uint256) public nftBonus;

    // Calculation variables
    uint256 public constant LATE_DAYS = 14;
    uint256 public constant MIN_STAKE_DAYS = 7;
    uint256 public constant MAX_STAKE_DAYS = 3333;
    uint256 public constant BASE_INFLATION = 18_185; // 18.185%
    uint256 public constant BASE_INFLATION_FACTOR = 100_000;
    uint256 public constant DAYS_IN_YEAR = 365;
    uint256 public constant PERCENT_FACTOR = 10_000_000_000; // was 10,000 now 1,000,000,000
    uint256 public constant MAGIC_NUMBER = 1111;
    uint256 public constant BPB_FACTOR = 10_000_000;

    uint256 public launchDate;

    /// @notice Maxx Finance Vault address
    address public maxxVault;

    /// @notice Maxx Finance token
    IMaxxFinance public maxx;
    /// @notice Stake Counter
    Counters.Counter public idCounter;
    /// @notice amount of shares all time
    uint256 public totalShares;
    /// @notice alltime stakes
    Counters.Counter public totalStakesAlltime;
    /// @notice all active stakes
    Counters.Counter public totalStakesActive;
    /// @notice number of withdrawn stakes
    Counters.Counter public totalStakesWithdrawn;
    /// @notice number of stakes that have ended but are not yet withdrawn
    uint256 public totalStakesMatured; // who is going to pay for the transaction to update this? // timed bot to update value?
    /// @notice amount of accrued interest
    uint256 public totalStakedOutstandingInterest; // who is going to pay for the transaction to update this?  // timed bot to update value?
    /// @notice percentage of nft bonus
    uint8 public nftBonusPercentage;
    /// @notice maxxBoost NFT
    IMAXXBoost public maxxBoost;
    /// @notice maxxGenesis NFT
    IMAXXBoost public maxxGenesis;
    /// @notice address of the freeClaim contract
    address public freeClaim;
    /// @notice address of the liquidityAmplifier contract
    address public liquidityAmplifier;
    /// mapping of stake end times
    mapping(uint256 => uint256) public endTimes;

    /// @notice Array of all stakes
    StakeData[] public stakes;

    // Base URI
    string private _baseUri;

    /// @notice Emitted when MAXX is staked
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
    event MaxxGenesisSet(address _maxxGenesis);
    event MaxxBoostSet(address _maxxBoost);
    event NftBonusPercentageSet(uint8 _nftBonusPercentage);
    event NftBonusSet(address _nft, uint256 _bonus);
    event BaseURISet(string _baseUri);
    event AcceptedNftAdded(address _nft);
    event AcceptedNftRemoved(address _nft);

    /// @dev Sets the `maxxVault` and `maxx` addresses and the `launchDate`
    constructor(
        address _maxxVault,
        address _maxx,
        uint256 _launchDate
    ) ERC721("MaxxStake", "SMAXX") {
        maxxVault = _maxxVault;
        maxx = IMaxxFinance(_maxx);
        launchDate = _launchDate; // launch date needs to be at least 60 days after liquidity amplifier start date
        // start stake ID at 1
        idCounter.increment();
        stakes.push(StakeData("", address(0), 0, 0, 0, 0, false)); // index 0 is null stake;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    function stake(uint16 _numDays, uint256 _amount) external {
        uint256 shares = _calcShares(_numDays, _amount);

        _stake(msg.sender, _numDays, _amount, shares);
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    /// @param _tokenId // The token Id of the nft to use
    /// @param _maxxNFT // The address of the nft collection to use
    function stake(
        uint16 _numDays,
        uint256 _amount,
        uint256 _tokenId,
        address _maxxNFT
    ) external {
        if (!isAcceptedNft[_maxxNFT]) {
            revert NftNotAccepted();
        }

        if (msg.sender != IMAXXBoost(_maxxNFT).ownerOf(_tokenId)) {
            revert IncorrectOwner();
        } else if (IMAXXBoost(_maxxNFT).getUsedState(_tokenId)) {
            revert UsedNFT();
        }
        IMAXXBoost(_maxxNFT).setUsed(_tokenId);

        uint256 shares = _calcShares(_numDays, _amount);
        shares += shares / nftBonus[_maxxNFT] / 100; // add nft bonus to the shares

        _stake(msg.sender, _numDays, _amount, shares);
    }

    /// @notice Function to unstake MAXX
    /// @param _stakeId The id of the stake to unstake
    function unstake(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        if (!_isApprovedOrOwner(msg.sender, _stakeId)) {
            revert NotAuthorized();
        }
        if (tStake.withdrawn) {
            revert StakeAlreadyWithdrawn();
        }
        stakes[_stakeId].withdrawn = true;
        totalStakesWithdrawn.increment();
        totalStakesActive.decrement();

        uint256 withdrawableAmount;
        uint256 penaltyAmount;
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days);
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );

        uint256 fullAmount = tStake.amount + interestToDate;
        if (daysServed < (tStake.duration / 1 days)) {
            // unstaking early
            // fee assessed
            withdrawableAmount =
                ((tStake.amount + interestToDate) * daysServed) /
                (tStake.duration / 1 days);
        } else if (daysServed > (tStake.duration / 1 days) + LATE_DAYS) {
            // unstaking late
            // fee assessed
            uint256 daysLate = daysServed -
                (tStake.duration / 1 days) -
                LATE_DAYS;
            uint64 penaltyPercentage = uint64(
                (PERCENT_FACTOR * daysLate) / DAYS_IN_YEAR
            );
            withdrawableAmount =
                ((tStake.amount + interestToDate) *
                    (PERCENT_FACTOR - penaltyPercentage)) /
                PERCENT_FACTOR;
        } else {
            // unstaking on time
            withdrawableAmount = tStake.amount + interestToDate;
        }
        penaltyAmount = fullAmount - withdrawableAmount;
        uint256 maxxBalance = maxx.balanceOf(address(this));

        if (fullAmount > maxxBalance) {
            maxx.mint(address(this), fullAmount - maxxBalance); // mint additional tokens to this contract
        }

        if (!maxx.transfer(msg.sender, withdrawableAmount)) {
            // transfer the withdrawable amount to the user
            revert TransferFailed();
        }
        if (penaltyAmount > 0) {
            if (!maxx.transfer(maxxVault, penaltyAmount / 2)) {
                // transfer half the penalty amount to the maxx vault
                revert TransferFailed();
            }
            maxx.burn(penaltyAmount / 2); // burn the other half of the penalty amount
        }

        emit Unstake(_stakeId, msg.sender, withdrawableAmount);
    }

    /// @notice Function to change stake to maximum duration without penalties
    /// @param _stakeId The id of the stake to change
    function maxShare(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        address stakeOwner = ownerOf(_stakeId);
        if (tStake.duration >= uint256(MAX_STAKE_DAYS) * 1 days) {
            revert AlreadyMaxDuration();
        }

        if (
            msg.sender != stakeOwner &&
            !isApprovedForAll(stakeOwner, msg.sender)
        ) {
            revert NotAuthorized();
        }
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days);
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );
        tStake.duration = uint256(MAX_STAKE_DAYS) * 1 days;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;

        tStake.amount += interestToDate;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;

        totalShares += tStake.shares;
        stakes[_stakeId] = tStake; // Update the stake in storage
        emit Stake(_stakeId, msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to restake without penalties
    /// @param _stakeId The id of the stake to restake
    /// @param _topUpAmount The amount of MAXX to top up the stake
    function restake(uint256 _stakeId, uint256 _topUpAmount)
        external
        nonReentrant
    {
        StakeData memory tStake = stakes[_stakeId];
        if (!_isApprovedOrOwner(msg.sender, _stakeId)) {
            revert NotAuthorized();
        }
        uint256 maturation = tStake.startDate + tStake.duration;
        if (block.timestamp < maturation) {
            revert StakeNotComplete();
        }
        if (_topUpAmount > maxx.balanceOf(msg.sender)) {
            revert InsufficientMaxx();
        }
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days);
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );
        tStake.amount += _topUpAmount + interestToDate;
        tStake.startDate = block.timestamp;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;
        totalShares += tStake.shares;
        stakes[_stakeId] = tStake;

        // transfer tokens to this contract
        if (!maxx.transferFrom(msg.sender, address(this), _topUpAmount)) {
            revert TransferFailed();
        }

        emit Stake(_stakeId, msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to transfer stake ownership
    /// @param _to The new owner of the stake
    /// @param _stakeId The id of the stake
    function transfer(address _to, uint256 _stakeId) external {
        address stakeOwner = ownerOf(_stakeId);
        if (msg.sender != stakeOwner) {
            revert NotAuthorized();
        }
        _transfer(msg.sender, _to, _stakeId);
    }

    /// @notice This function changes the name of a stake
    /// @param _stakeId The id of the stake
    /// @param _stakeName The new name of the stake
    function changeStakeName(uint256 _stakeId, string memory _stakeName)
        external
    {
        address stakeOwner = ownerOf(_stakeId);
        if (
            msg.sender != stakeOwner &&
            !isApprovedForAll(stakeOwner, msg.sender)
        ) {
            revert NotAuthorized();
        }

        stakes[_stakeId].name = _stakeName;
        emit StakeNameChange(_stakeId, _stakeName);
    }

    /// @notice Function to stake MAXX from liquidity amplifier contract
    /// @param _numDays The number of days to stake for
    /// @param _amount The amount of MAXX to stake
    function amplifierStake(
        address _owner,
        uint16 _numDays,
        uint256 _amount
    ) external returns (uint256 stakeId, uint256 shares) {
        if (msg.sender != liquidityAmplifier) {
            revert NotAuthorized();
        }

        shares = _calcShares(_numDays, _amount);
        if (_numDays >= DAYS_IN_YEAR) {
            shares = (shares * 11) / 10;
        }

        stakeId = _stake(_owner, _numDays, _amount, shares);
        return (stakeId, shares);
    }

    /// @notice Function to stake MAXX from FreeClaim contract
    /// @param _owner The owner of the stake
    /// @param _numDays The number of days to stake for
    /// @param _amount The amount of MAXX to stake
    function freeClaimStake(
        address _owner,
        uint16 _numDays,
        uint256 _amount
    ) external returns (uint256 stakeId, uint256 shares) {
        if (msg.sender != freeClaim) {
            revert NotAuthorized();
        }

        shares = _calcShares(_numDays, _amount);

        stakeId = _stake(_owner, _numDays, _amount, shares);

        return (stakeId, shares);
    }

    /// @notice Funciton to set liquidityAmplifier contract address
    /// @param _liquidityAmplifier The address of the liquidityAmplifier contract
    function setLiquidityAmplifier(address _liquidityAmplifier)
        external
        onlyOwner
    {
        liquidityAmplifier = _liquidityAmplifier;
        emit LiquidityAmplifierSet(_liquidityAmplifier);
    }

    /// @notice Function to set freeClaim contract address
    /// @param _freeClaim The address of the freeClaim contract
    function setFreeClaim(address _freeClaim) external onlyOwner {
        freeClaim = _freeClaim;
        emit FreeClaimSet(_freeClaim);
    }

    /// @notice Function to set the NFT bonus percentage
    /// @param _nftBonusPercentage The percentage of NFT bonus (e.g. 20 = 20%)
    function setNftBonusPercentage(uint8 _nftBonusPercentage)
        external
        onlyOwner
    {
        nftBonusPercentage = _nftBonusPercentage;
        emit NftBonusPercentageSet(_nftBonusPercentage);
    }

    /// @notice Function to set the MaxxBoost NFT contract address
    /// @param _maxxBoost Address of the MaxxBoost NFT contract
    function setMaxxBoost(address _maxxBoost) external onlyOwner {
        if (!IERC721(_maxxBoost).supportsInterface(type(IERC721).interfaceId)) {
            // must support IERC721 interface
            revert InterfaceNotSupported(_maxxBoost);
        }
        maxxBoost = IMAXXBoost(_maxxBoost);
        emit MaxxBoostSet(_maxxBoost);
    }

    /// @notice Function to set the MaxxGenesis NFT contract address
    /// @param _maxxGenesis Address of the MaxxGenesis NFT contract
    function setMaxxGenesis(address _maxxGenesis) external onlyOwner {
        if (
            !IERC721(_maxxGenesis).supportsInterface(type(IERC721).interfaceId)
        ) {
            // must support IERC721 interface
            revert InterfaceNotSupported(_maxxGenesis);
        }
        maxxGenesis = IMAXXBoost(_maxxGenesis);
        emit MaxxGenesisSet(_maxxGenesis);
    }

    /// @notice Add an accepted NFT
    /// @param _nft The address of the NFT contract
    function addAcceptedNft(address _nft) external onlyOwner {
        isAcceptedNft[_nft] = true;
        emit AcceptedNftAdded(_nft);
    }

    /// @notice Remove an accepted NFT
    /// @param _nft The address of the NFT to remove
    function removeAcceptedNft(address _nft) external onlyOwner {
        isAcceptedNft[_nft] = false;
        emit AcceptedNftRemoved(_nft);
    }

    /// @notice Set the staking bonus for `_nft` to `_bonus`
    /// @param _nft The NFT contract address
    /// @param _bonus The bonus percentage (e.g. 20 = 20%)
    function setNftBonus(address _nft, uint256 _bonus) external onlyOwner {
        nftBonus[_nft] = _bonus;
        emit NftBonusSet(_nft, _bonus);
    }

    /// @notice Set the baseURI for the token collection
    /// @param baseURI_ The baseURI for the token collection
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseUri = baseURI_;
        emit BaseURISet(baseURI_);
    }

    /// @notice Function to change the start date
    /// @dev Cannot change the start date after the day has passed
    /// @param _launchDate New start date
    function changeLaunchDate(uint256 _launchDate) external onlyOwner {
        if (block.timestamp >= launchDate || block.timestamp >= _launchDate) {
            revert LaunchDatePassed();
        }
        launchDate = _launchDate;
        emit LaunchDateUpdated(_launchDate);
    }

    /// @notice Get the stakes array
    /// @return stakes The stakes array
    function getAllStakes() external view returns (StakeData[] memory) {
        return stakes;
    }

    /// @notice Get the `count` stakes starting from `index`
    /// @param index The index to start from
    /// @param count The number of stakes to return
    /// @return result An array of StakeData
    function getStakes(uint256 index, uint256 count)
        external
        view
        returns (StakeData[] memory result)
    {
        uint256 inserts;
        for (uint256 i = index; i < index + count; i++) {
            result[inserts] = (stakes[i]);
            ++inserts;
        }
        return result;
    }

    /// @notice This function will return day `day` since the launch date
    /// @return day The number of days passed since `launchDate`
    function getDaysSinceLaunch() public view returns (uint256 day) {
        day = (block.timestamp - launchDate) / 60 / 60 / 24; // divide by 60 seconds, 60 minutes, 24 hours
        return day;
    }

    /// @notice Function that returns whether `interfaceId` is supported by this contract
    /// @param interfaceId The interface ID to check
    /// @return Whether `interfaceId` is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Returns the base URI for the token collection
    function tokenURI(uint256) public view override returns (string memory) {
        return _baseURI();
    }

    function _stake(
        address _owner,
        uint16 _numDays,
        uint256 _amount,
        uint256 _shares
    ) internal returns (uint256 stakeId) {
        if (_numDays < MIN_STAKE_DAYS) {
            revert StakeTooShort();
        } else if (_numDays > MAX_STAKE_DAYS) {
            revert StakeTooLong();
        }

        if (
            maxx.hasRole(maxx.MINTER_ROLE(), msg.sender) &&
            maxx.balanceOf(_owner) == _amount &&
            msg.sender != freeClaim &&
            msg.sender != liquidityAmplifier
        ) {
            maxx.mint(msg.sender, 1);
        }

        // transfer tokens to this contract -- removed from circulating supply
        if (!maxx.transferFrom(msg.sender, address(this), _amount)) {
            revert TransferFailed();
        }

        totalShares += _shares;
        totalStakesAlltime.increment();
        totalStakesActive.increment();

        uint256 duration = uint256(_numDays) * 1 days;
        stakeId = idCounter.current();
        assert(stakeId == stakes.length);
        stakes.push(
            StakeData(
                "",
                _owner,
                _amount,
                _shares,
                duration,
                block.timestamp,
                false
            )
        );

        endTimes[stakeId] = block.timestamp + duration;

        _mint(_owner, stakeId);

        emit Stake(idCounter.current(), _owner, _numDays, _amount);
        idCounter.increment();
        return stakeId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        stakes[tokenId].owner = to;
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /// @dev Calculate shares using following formula: (amount / (2-SF)) + (((amount / (2-SF)) * (Duration-1)) / MN)
    /// @return shares The number of shares for the full-term stake
    function _calcShares(uint16 duration, uint256 _amount)
        internal
        view
        returns (uint256 shares)
    {
        uint256 shareFactor = _getShareFactor();

        uint256 basicShares = _amount / (2 - shareFactor);
        uint256 bpbBonus = _amount / BPB_FACTOR;
        if (bpbBonus > 10) {
            bpbBonus = 10;
        }
        uint256 bpbShares = (basicShares * bpbBonus) / 100; // bigger pays better
        uint256 lpbShares = ((basicShares + bpbShares) * (duration - 1)) /
            MAGIC_NUMBER; // longer pays better
        shares = basicShares + bpbShares + lpbShares;
        return shares;
    }

    /// @return shareFactor The current share factor
    function _getShareFactor() internal view returns (uint256 shareFactor) {
        shareFactor = 1 - (getDaysSinceLaunch() / MAX_STAKE_DAYS);
        assert(shareFactor <= 1);
        return shareFactor;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }

    /// @dev Calculate interest for a given number of shares and duration
    /// @return interestToDate The interest accrued to date
    function _calcInterestToDate(
        uint256 _stakeTotalShares,
        uint256 _daysServed,
        uint256 _duration
    ) internal pure returns (uint256 interestToDate) {
        uint256 stakeDuration = _duration / 1 days;
        uint256 fullDurationInterest = (_stakeTotalShares *
            BASE_INFLATION *
            stakeDuration) /
            DAYS_IN_YEAR /
            BASE_INFLATION_FACTOR;

        uint256 currentDurationInterest = (_daysServed *
            _stakeTotalShares *
            stakeDuration *
            BASE_INFLATION) /
            stakeDuration /
            BASE_INFLATION_FACTOR /
            DAYS_IN_YEAR;

        if (currentDurationInterest > fullDurationInterest) {
            interestToDate = fullDurationInterest;
        } else {
            interestToDate = currentDurationInterest;
        }
        return interestToDate;
    }
}
