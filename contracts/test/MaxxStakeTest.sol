// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ILiquidityAmplifier} from "../interfaces/ILiquidityAmplifier.sol";
import {IMaxxFinance} from "../interfaces/IMaxxFinance.sol";
import {IMAXXBoost} from "../interfaces/IMAXXBoost.sol";
import {IFreeClaim} from "../interfaces/IFreeClaim.sol";
import {IStake} from "../interfaces/IStake.sol";

/// @title Maxx Finance staking contract
/// @author Alta Web3 Labs - SonOfMosiah
contract MaxxStakeTest is
    IStake,
    ERC721,
    ERC721Enumerable,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using ERC165Checker for address;
    using Counters for Counters.Counter;
    using Strings for uint256;

    /// mapping of accepted NFTs
    mapping(address => bool) public isAcceptedNft;
    /// @dev 10 = 10% boost
    mapping(address => uint256) public nftBonus;
    /// mapping of stake end times
    mapping(uint256 => uint256) public endTimes;

    uint256 private constant _TEST_TIME_FACTOR = 672; // Test contract runs 336x faster (1 hour = 2 weeks)

    // Calculation variables
    uint256 public constant LATE_DAYS = 14;
    uint256 public constant MIN_STAKE_DAYS = 7;
    uint256 public constant MAX_STAKE_DAYS = 3333;
    uint256 public constant DAYS_IN_YEAR = 365;
    uint256 public constant BASE_INFLATION = 18_185; // 18.185%
    uint256 public constant BASE_INFLATION_FACTOR = 100_000;
    uint256 public constant PERCENT_FACTOR = 1e10;
    uint256 public constant MAGIC_NUMBER = 1111;
    uint256 public constant BPB_FACTOR = 2e24;
    uint256 private constant _SHARE_FACTOR = 1e9;

    uint256 public launchDate;

    /// @notice Maxx Finance Vault address
    address public maxxVault;
    /// @notice address of the freeClaim contract
    address public freeClaim;
    /// @notice address of the liquidityAmplifier contract
    address public liquidityAmplifier;
    /// @notice Maxx Finance token
    IMaxxFinance public maxx;

    /// @notice amount of shares all time
    uint256 public totalShares;
    /// @notice amount of maxx currently staked
    uint256 public totalStaked;
    /// @notice Stake Counter
    Counters.Counter public idCounter;
    /// @notice alltime stakes
    Counters.Counter public totalStakesAlltime;
    /// @notice all active stakes
    Counters.Counter public totalStakesActive;
    /// @notice number of withdrawn stakes
    Counters.Counter public totalStakesWithdrawn;

    /// @notice Array of all stakes
    StakeData[] public stakes;

    // Base URI
    string private _baseUri;
    uint256 private _lastMigrationValue;

    constructor() ERC721("MaxxStake", "SMAXX") {
        // start stake ID at 1
        idCounter.increment();
        stakes.push(StakeData("", address(0), 0, 0, 0, 0, false)); // index 0 is null stake;
    }

    /// @notice Sets the `maxxVault` and `maxx` addresses and the `launchDate`
    /// @param _maxxVault Maxx Finance Vault address
    /// @param _maxx Maxx Finance token address
    /// @param _launchDate The launch date
    function init(
        address _maxxVault,
        address _maxx,
        uint256 _launchDate
    ) external onlyOwner {
        if (_maxxVault == address(0) || _maxx == address(0)) {
            revert ZeroAddress();
        }
        maxxVault = _maxxVault;
        maxx = IMaxxFinance(_maxx);
        launchDate = _launchDate; // launch date needs to be after the liquidity amplifier ends
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    function stake(uint256 _numDays, uint256 _amount) external {
        if (_amount < 5e22) {
            revert InvalidAmount();
        }
        uint256 shares = _calcShares(_numDays, _amount);

        _stake(msg.sender, _numDays, _amount, shares);
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    /// @param _tokenId The token Id of the nft to use
    /// @param _maxxNFT The address of the nft collection to use
    function stake(
        uint256 _numDays,
        uint256 _amount,
        uint256 _tokenId,
        address _maxxNFT
    ) external {
        if (_amount < 5e22) {
            revert InvalidAmount();
        }
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
        shares += ((shares * nftBonus[_maxxNFT]) / 100); // add nft bonus to the shares

        _stake(msg.sender, _numDays, _amount, shares);
    }

    /// @notice Function to unstake MAXX
    /// @param _stakeId The id of the stake to unstake
    function unstake(uint256 _stakeId) external nonReentrant {
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

        _burn(_stakeId);

        uint256 withdrawableAmount;
        uint256 penaltyAmount;
        uint256 daysServed = (((block.timestamp - tStake.startDate) *
            _TEST_TIME_FACTOR) / 1 days);
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );

        totalStaked -= tStake.amount;
        maxx.mint(address(this), interestToDate); // mint the interest to this contract

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
            if (penaltyPercentage > PERCENT_FACTOR) {
                withdrawableAmount = 0;
            } else {
                withdrawableAmount =
                    ((tStake.amount + interestToDate) *
                        (PERCENT_FACTOR - penaltyPercentage)) /
                    PERCENT_FACTOR;
            }
        } else {
            // unstaking on time
            withdrawableAmount = tStake.amount + interestToDate;
        }
        penaltyAmount = fullAmount - withdrawableAmount;

        if (withdrawableAmount > 0) {
            if (!maxx.transfer(msg.sender, withdrawableAmount)) {
                // transfer the withdrawable amount to the user
                revert TransferFailed();
            }
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
        uint256 _numDays,
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
        uint256 _numDays,
        uint256 _amount
    ) external returns (uint256 stakeId, uint256 shares) {
        if (msg.sender != freeClaim) {
            revert NotAuthorized();
        }

        shares = _calcShares(_numDays, _amount);

        stakeId = _stake(_owner, _numDays, _amount, shares);

        return (stakeId, shares);
    }

    /// @notice Stake unstaked free claims in batches
    /// @param amount The amount of free claims to stake
    function migrateUnstakedFreeClaims(uint256 amount) external onlyOwner {
        uint256[] memory claimIds = IFreeClaim(freeClaim)
            .getUnstakedClaimsSlice(
                _lastMigrationValue,
                _lastMigrationValue + amount
            );

        for (uint256 i = 0; i < amount; i++) {
            IFreeClaim(freeClaim).stakeClaim(i, claimIds[i]);
        }
        _lastMigrationValue += amount;
    }

    /// @notice Burn stakes that are over a year late
    /// @param stakeIds The ids of the stakes to burn
    function burnDeadStakes(uint256[] calldata stakeIds) external onlyOwner {
        uint256 penaltyAmount;
        uint256 principalAmount;
        for (uint256 i = 0; i < stakeIds.length; i++) {
            StakeData memory tStake = stakes[stakeIds[i]];
            uint256 daysServed = (((block.timestamp - tStake.startDate) *
                _TEST_TIME_FACTOR) / 1 days);
            uint256 interestToDate = _calcInterestToDate(
                tStake.shares,
                daysServed,
                tStake.duration
            );
            uint256 fullAmount = tStake.amount + interestToDate;
            uint256 daysLate = daysServed - (tStake.duration / 1 days);
            if (daysLate > DAYS_IN_YEAR) {
                _burn(stakeIds[i]);
                principalAmount += tStake.amount;
                penaltyAmount += fullAmount;
                emit Unstake(stakeIds[i], tStake.owner, 0);
            }
        }

        if (penaltyAmount > 0) {
            maxx.mint(address(this), penaltyAmount - principalAmount);
            totalStaked -= principalAmount;
            if (!maxx.transfer(maxxVault, penaltyAmount / 2)) {
                // transfer half the penalty amount to the maxx vault
                revert TransferFailed();
            }
            maxx.burn(penaltyAmount / 2); // burn the other half of the penalty amount
        }
    }

    /// @notice Function to set liquidityAmplifier contract address
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
        day = ((block.timestamp - launchDate) * _TEST_TIME_FACTOR) / 1 days;
        return day;
    }

    /// @notice Function that returns whether `interfaceId` is supported by this contract
    /// @param interfaceId The interface ID to check
    /// @return Whether `interfaceId` is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Returns the token URI
    /// @param stakeId The id of the stake
    /// @return The token URI
    function tokenURI(uint256 stakeId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireMinted(stakeId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, stakeId.toString()))
                : "";
    }

    /// @return shareFactor The current share factor
    function getShareFactor() public view returns (uint256 shareFactor) {
        uint256 day = getDaysSinceLaunch();
        if (day >= MAX_STAKE_DAYS) {
            return 0;
        }
        shareFactor =
            _SHARE_FACTOR -
            ((getDaysSinceLaunch() * _SHARE_FACTOR) / MAX_STAKE_DAYS);
        return shareFactor;
    }

    function _stake(
        address _owner,
        uint256 _numDays,
        uint256 _amount,
        uint256 _shares
    ) internal returns (uint256 stakeId) {
        // Check that stake duration is valid
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
        totalStaked += _amount;
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

        endTimes[stakeId] = block.timestamp + (duration / _TEST_TIME_FACTOR);

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
    function _calcShares(uint256 duration, uint256 _amount)
        internal
        view
        returns (uint256 shares)
    {
        uint256 shareFactor = getShareFactor();

        uint256 basicShares = (_amount * _SHARE_FACTOR) /
            ((2 * _SHARE_FACTOR) - shareFactor);
        uint256 bpbBonus = _amount / (BPB_FACTOR / 10);
        if (bpbBonus > 100) {
            bpbBonus = 100;
        }
        uint256 bpbShares = (basicShares * bpbBonus) / 1_000; // bigger pays better
        uint256 lpbShares = ((basicShares + bpbShares) * (duration - 1)) /
            MAGIC_NUMBER; // longer pays better
        shares = basicShares + bpbShares + lpbShares;
        return shares;
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
