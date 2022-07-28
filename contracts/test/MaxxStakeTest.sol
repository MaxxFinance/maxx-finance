// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {ILiquidityAmplifier} from "../interfaces/ILiquidityAmplifier.sol";
import {IMaxxFinance} from "../interfaces/IMaxxFinance.sol";
import {IMAXXBoost} from "../interfaces/IMAXXBoost.sol";

/// Not authorized to control the stake
error NotAuthorized();

/// The stake is already approved
error AlreadyApproved();

/// Stake owner is attempting to approve themselves
error SelfApproval();

/// The spender is not approved to transfer the stake
error UnauthorizedTransfer();

/// Cannot stake less than {MIN_STAKE_DAYS} days
error StakeTooShort();

/// Cannot stake more than {MAX_STAKE_DAYS} days
error StakeTooLong();

/// Address does not own enough MAXX tokens
error InsufficientMaxx();

/// Stake has not yet completed
error StakeNotComplete();

/// Stake has already matured
error StakeMatured();

/// Stake does not exist
error StakeDoesNotExist();

/// Cannot transfer stake to zero address
error TransferToTheZeroAddress();

/// User does not own the NFT
error NotNFTOwner();

/// NFT boost has already been used
error UsedNFT();

/// @title Maxx Finance staking contract
/// @author Alta Web3 Labs - SonOfMosiah
contract MaxxStakeTest is Ownable {
    uint16 private constant TEST_TIME_FACTOR = 168; // Test contract runs 168x faster (1 hour = 1 week)
    using ERC165Checker for address;
    using Counters for Counters.Counter;

    // Calculation variables
    uint256 immutable launchDate;
    uint8 private constant LATE_DAYS = 14;
    uint8 private constant MIN_STAKE_DAYS = 7;
    uint16 private constant MAX_STAKE_DAYS = 3333;
    uint8 private constant BASE_INFLATION = 10; // 10%
    uint8 private constant BASE_INFLATION_FACTOR = 100;
    uint16 private constant DAYS_IN_YEAR = 365;
    uint256 private constant PERCENT_FACTOR = 10000000000; // was 10,000 now 1,000,000,000
    uint256 private constant MAGIC_NUMBER = 1111;

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
    /// @notice mapping of stake id to stake
    mapping(uint256 => StakeData) public stakes; // TODO: change to array to iterate over all stakes
    /// mapping of stake end times
    mapping(uint256 => uint256) public endTimes;

    // StakeData[] public stakes;
    // StakeData[] public activeStakes;
    // StakeData[] public withdrawnStakes;

    /// @notice mapping of stake id to withdrawn amounts
    mapping(uint256 => uint256) public withdrawnAmounts;

    // Mapping of stake to owner
    mapping(uint256 => address) private _owners;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _stakeApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /// @notice Emitted when MAXX is staked
    /// @param user The user staking MAXX
    /// @param numDays The number of days staked
    /// @param amount The amount of MAXX staked
    event Stake(address indexed user, uint16 numDays, uint256 amount);

    /// @notice Emitted when MAXX is unstaked
    /// @param user The user unstaking MAXX
    /// @param amount The amount of MAXX unstaked
    event Unstake(address indexed user, uint256 amount);

    /// @notice Emitted when stake is transferred
    /// @param oldOwner The user transferring the stake
    /// @param newOwner The user receiving the stake
    event Transfer(address indexed oldOwner, address indexed newOwner);

    /// @dev Emitted when `owner` enables `approved` to manage the `stakeId` token.
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 stakeId
    );

    /// @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /// @notice Emitted when interest is scraped early
    /// @param user The user who scraped interest
    /// @param amount The amount of interest scraped
    event ScrapeInterest(address indexed user, uint256 amount);

    /// @notice Emitted when the name of a stake is changed
    /// @param stakeId The id of the stake
    /// @param name The new name of the stake
    event StakeNameChange(uint256 stakeId, string name);

    struct StakeData {
        string name; // 32 letters max
        uint256 amount;
        uint256 shares;
        uint256 duration;
        uint256 startDate;
    }

    enum MaxxNFT {
        MaxxGenesis,
        MaxxBoost
    }

    constructor(
        address _maxxVault,
        address _maxx,
        uint256 _launchDate,
        address _maxxBoost,
        address _maxxGenesis
    ) {
        maxxVault = _maxxVault;
        maxx = IMaxxFinance(_maxx);
        launchDate = _launchDate; // launch date needs to be at least 60 days after liquidity amplifier start date
        maxxBoost = IMAXXBoost(_maxxBoost);
        maxxGenesis = IMAXXBoost(_maxxGenesis);
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    function stake(uint16 _numDays, uint256 _amount) external {
        uint256 shares = _calcShares(_numDays, _amount);

        _stake(_numDays, _amount, shares);
        _owners[idCounter.current()] = msg.sender;
    }

    /// @notice Function to stake MAXX
    /// @dev User must approve MAXX before staking
    /// @param _numDays The number of days to stake (min 7, max 3333)
    /// @param _amount The amount of MAXX to stake
    /// @param _tokenId // The token Id of the nft to use
    /// @param _maxxNFT // The nft collection to use
    function stake(
        uint16 _numDays,
        uint256 _amount,
        uint256 _tokenId,
        MaxxNFT _maxxNFT
    ) external {
        IMAXXBoost nft;
        if (_maxxNFT == MaxxNFT.MaxxGenesis) {
            nft = maxxGenesis;
        } else {
            nft = maxxBoost;
        }

        if (msg.sender != nft.ownerOf(_tokenId)) {
            revert NotNFTOwner();
        } else if (nft.getUsedState(_tokenId)) {
            revert UsedNFT();
        }
        nft.setUsed(_tokenId);

        uint256 shares = _calcShares(_numDays, _amount);
        shares += shares / 10; // add 10% to the shares for the nft bonus

        _stake(_numDays, _amount, shares);
        _owners[idCounter.current()] = msg.sender;
    }

    /// @notice Function to unstake MAXX
    /// @param _stakeId The id of the stake to unstake
    function unstake(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        address owner = ownerOf(_stakeId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }
        totalStakesWithdrawn.increment();
        totalStakesActive.decrement();

        uint256 withdrawableAmount;
        uint256 penaltyAmount;
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days) *
            TEST_TIME_FACTOR;
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );
        interestToDate = interestToDate - withdrawnAmounts[_stakeId]; // TODO: check if this affects the ensuing math calculations

        uint256 fullAmount = tStake.amount + interestToDate;
        if (daysServed < (tStake.duration / 1 days)) {
            // unstaking early
            // fee assessed
            withdrawableAmount =
                ((tStake.amount + interestToDate) * daysServed) /
                tStake.duration /
                1 days;
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
        withdrawnAmounts[_stakeId] = withdrawableAmount;
        uint256 maxxBalance = maxx.balanceOf(address(this));

        if (fullAmount > maxxBalance) {
            maxx.mint(address(this), fullAmount - maxxBalance); // mint additional tokens to this contract
        }

        require(maxx.transfer(msg.sender, withdrawableAmount)); // transfer the withdrawable amount to the user
        if (penaltyAmount > 0) {
            require(maxx.transfer(maxxVault, penaltyAmount / 2)); // transfer half the penalty amount to the maxx vault
            maxx.burn(penaltyAmount / 2); // burn the other half of the penalty amount
        }

        emit Unstake(msg.sender, withdrawableAmount);
    }

    /// @notice Function to change stake to maximum duration without penalties
    /// @param _stakeId The id of the stake to change
    function maxShare(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        address owner = ownerOf(_stakeId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days) *
            TEST_TIME_FACTOR;
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );
        interestToDate = interestToDate - withdrawnAmounts[_stakeId];
        tStake.duration = uint256(MAX_STAKE_DAYS) * 1 days;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;

        tStake.amount += interestToDate;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;

        totalShares += tStake.shares;
        stakes[_stakeId] = tStake; // Update the stake in storage
        emit Stake(msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to restake without penalties
    /// @param _stakeId The id of the stake to restake
    /// @param _topUpAmount The amount of MAXX to top up the stake
    function restake(uint256 _stakeId, uint256 _topUpAmount) external {
        StakeData memory tStake = stakes[_stakeId];
        address owner = ownerOf(_stakeId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }
        uint256 maturation = tStake.startDate + tStake.duration;
        if (block.timestamp < maturation) {
            revert StakeNotComplete();
        }
        if (_topUpAmount > maxx.balanceOf(msg.sender)) {
            revert InsufficientMaxx();
        }
        require(maxx.transferFrom(msg.sender, address(this), _topUpAmount)); // transfer tokens to this contract
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days) *
            TEST_TIME_FACTOR;
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );
        interestToDate = interestToDate - withdrawnAmounts[_stakeId];
        tStake.amount += _topUpAmount + interestToDate;
        tStake.startDate = block.timestamp;
        uint16 durationInDays = uint16(tStake.duration / 24 / 60 / 60);
        totalShares -= tStake.shares;
        tStake.shares = _calcShares(durationInDays, tStake.amount);
        tStake.startDate = block.timestamp;
        totalShares += tStake.shares;
        stakes[_stakeId] = tStake;
        emit Stake(msg.sender, durationInDays, tStake.amount);
    }

    /// @notice Function to transfer stake ownership
    /// @param _to The new owner of the stake
    /// @param _stakeId The id of the stake
    function transfer(address _to, uint256 _stakeId) external {
        if (!_isApprovedOrOwner(msg.sender, _stakeId)) {
            revert NotAuthorized();
        }
        _transferStake(_stakeId, _to);
    }

    /// @notice Function for an external address to transfer stake ownership with an allowance
    /// @dev Only removes the allowance from the calling address, if multiple addresses were given an allowance, they will persist
    /// @param _from The address of the old owner of the stake
    /// @param _to The address to the new owner of the stake
    /// @param _stakeId The id of the stake
    function transferFrom(
        address _from,
        address _to,
        uint256 _stakeId
    ) external {
        if (!_isApprovedOrOwner(msg.sender, _stakeId)) {
            revert NotAuthorized();
        }
        if (_from != ownerOf(_stakeId)) {
            revert NotAuthorized();
        }
        _transferStake(_stakeId, _to);
    }

    /// @notice Function to withdraw interest early from a stake
    /// @param _stakeId The id of the stake
    function scrapeInterest(uint256 _stakeId) external {
        StakeData memory tStake = stakes[_stakeId];
        address owner = ownerOf(_stakeId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }

        if (block.timestamp > endTimes[_stakeId]) {
            revert StakeMatured();
        }
        uint256 daysServed = ((block.timestamp - tStake.startDate) / 1 days) *
            TEST_TIME_FACTOR;
        uint256 interestToDate = _calcInterestToDate(
            tStake.shares,
            daysServed,
            tStake.duration
        );

        if (interestToDate > maxx.balanceOf(address(this))) {
            maxx.mint(
                address(this),
                interestToDate - maxx.balanceOf(address(this))
            ); // mint additional tokens to this contract
        }

        uint256 durationInDays = tStake.duration / 1 days;

        uint256 percentServed = (daysServed * PERCENT_FACTOR) / durationInDays;

        uint256 withdrawableAmount = (interestToDate * percentServed) /
            PERCENT_FACTOR;
        uint256 penaltyAmount = interestToDate - withdrawableAmount;
        withdrawnAmounts[_stakeId] = interestToDate;
        require(maxx.transfer(msg.sender, withdrawableAmount));

        require(maxx.transfer(maxxVault, penaltyAmount / 2));
        maxx.burn(penaltyAmount / 2);

        emit ScrapeInterest(msg.sender, interestToDate);
    }

    /// @notice This function changes the name of a stake
    /// @param _stakeId The id of the stake
    /// @param _name The new name of the stake
    function changeStakeName(uint256 _stakeId, string memory _name) external {
        address owner = ownerOf(_stakeId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }

        stakes[_stakeId].name = _name;
        emit StakeNameChange(_stakeId, _name);
    }

    /// @notice Function to stake MAXX from liquidity amplifier contract
    /// @param _numDays The number of days to stake for
    /// @param _amount The amount of MAXX to stake
    function amplifierStake(uint16 _numDays, uint256 _amount) external {
        if (msg.sender != liquidityAmplifier) {
            revert NotAuthorized();
        }

        uint256 shares = _calcShares(_numDays, _amount);
        if (_numDays >= DAYS_IN_YEAR) {
            // TODO: calculate the bonus amount of shares
            // e.g. shares = shares * 10%
        }

        _stake(_numDays, _amount, shares);
        _owners[idCounter.current()] = tx.origin;
    }

    /// @notice Function to stake MAXX from liquidity amplifier contract
    /// @param _numDays The number of days to stake for
    /// @param _amount The amount of MAXX to stake
    /// @param _tokenId // The token Id of the nft to use
    /// @param _maxxNFT // The nft collection to use
    function amplifierStake(
        uint16 _numDays,
        uint256 _amount,
        uint256 _tokenId,
        MaxxNFT _maxxNFT
    ) external {
        if (msg.sender != liquidityAmplifier) {
            revert NotAuthorized();
        }

        IMAXXBoost nft;
        if (_maxxNFT == MaxxNFT.MaxxGenesis) {
            nft = maxxGenesis;
        } else {
            nft = maxxBoost;
        }

        if (msg.sender != nft.ownerOf(_tokenId)) {
            revert NotNFTOwner();
        } else if (nft.getUsedState(_tokenId)) {
            revert UsedNFT();
        }
        nft.setUsed(_tokenId);

        uint256 shares = _calcShares(_numDays, _amount);
        shares += shares / 10; // add 10% to the shares for the nft bonus
        if (_numDays >= DAYS_IN_YEAR) {
            // TODO: calculate the bonus amount of shares
            // e.g. shares = shares * 10%
        }

        _stake(_numDays, _amount, shares);

        _owners[idCounter.current()] = tx.origin;
    }

    /// @notice Function to stake MAXX from FreeClaim contract
    /// @param _owner The owner of the stake
    /// @param _amount The amount of MAXX to stake
    function freeClaimStake(address _owner, uint256 _amount) external {
        if (msg.sender != freeClaim) {
            revert NotAuthorized();
        }

        uint256 shares = _calcShares(DAYS_IN_YEAR, _amount);

        _stake(DAYS_IN_YEAR, _amount, shares);

        _owners[idCounter.current()] = _owner;
    }

    /// @notice Funciton to set liquidityAmplifier contract address
    /// @param _liquidityAmplifier The address of the liquidityAmplifier contract
    function setLiquidityAmplifier(address _liquidityAmplifier)
        external
        onlyOwner
    {
        liquidityAmplifier = _liquidityAmplifier;
    }

    /// @notice Function to set freeClaim contract address
    /// @param _freeClaim The address of the freeClaim contract
    function setFreeClaim(address _freeClaim) external onlyOwner {
        freeClaim = _freeClaim;
    }

    /// @notice Function to set the NFT bonus percentage
    /// @param _nftBonusPercentage The percentage of NFT bonus (e.g. 20 = 20%)
    function setNftBonusPercentage(uint8 _nftBonusPercentage)
        external
        onlyOwner
    {
        nftBonusPercentage = _nftBonusPercentage;
    }

    /// @notice Function to set the MaxxBoost NFT contract address
    /// @param _maxxBoost Address of the MaxxBoost NFT contract
    function setMaxxBoost(address _maxxBoost) external onlyOwner {
        require(
            IERC721(_maxxBoost).supportsInterface(type(IERC721).interfaceId)
        ); // must support IERC721 interface
        maxxBoost = IMAXXBoost(_maxxBoost);
    }

    /// @notice Function to set the MaxxGenesis NFT contract address
    /// @param _maxxGenesis Address of the MaxxGenesis NFT contract
    function setMaxxGenesis(address _maxxGenesis) external onlyOwner {
        require(
            IERC721(_maxxGenesis).supportsInterface(type(IERC721).interfaceId)
        ); // must support IERC721 interface
        maxxGenesis = IMAXXBoost(_maxxGenesis);
    }

    /// @dev Gives permission to `_to` to transfer `_stakeId` token to another account.
    /// @param _to The address given approval
    /// @param _stakeId The id of the stake to be approved for transfer
    function approve(address _to, uint256 _stakeId) public {
        address owner = ownerOf(_stakeId);
        if (_to == owner) {
            revert SelfApproval();
        }
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotAuthorized();
        }

        _approve(_to, _stakeId);
    }

    /// @notice Approve or remove `operator` as an operator for the caller.
    /// @dev Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
    /// @param _operator The account that will be added or removed as an operator.
    /// @param _approved Whether the account is added or removed as an operator.
    function setApprovalForAll(address _operator, bool _approved) public {
        _setApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice This function will return day `day` since the launch date
    /// @return day The number of days passed since `launchDate`
    function getDaysSinceLaunch() public view returns (uint256 day) {
        day =
            ((block.timestamp - launchDate) * TEST_TIME_FACTOR) /
            60 /
            60 /
            24; // divide by 60 seconds, 60 minutes, 24 hours
        return day;
    }

    /// @dev Returns the owner of the `_stakeId` token.
    /// @param _stakeId The id of the stake
    /// @return The owner of the stake
    function ownerOf(uint256 _stakeId) public view returns (address) {
        address owner = _owners[_stakeId];
        if (owner == address(0)) {
            revert StakeDoesNotExist();
        }
        return owner;
    }

    /// @notice Returns the account approved for `_stakeId` token.
    /// @param _stakeId The id of the stake
    /// @return operator The account approved for `_stakeId` token.
    function getApproved(uint256 _stakeId)
        public
        view
        returns (address operator)
    {
        _requireStaked(_stakeId);

        return _stakeApprovals[_stakeId];
    }

    /// @notice Returns if the `operator` is allowed to manage all of the assets of `owner`.
    /// @param _owner The account owning the stakes.
    /// @param _operator The account to check for operating approval.
    /// @return True if `operator` is allowed to manage all of the stakes of `owner`.
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        returns (bool)
    {
        return _operatorApprovals[_owner][_operator];
    }

    function _approve(address _to, uint256 _stakeId) internal {
        _stakeApprovals[_stakeId] = _to;
        emit Approval(ownerOf(_stakeId), _to, _stakeId);
    }

    /// @dev Approve `_operator` to operate on all of `_owner` stakes
    function _setApprovalForAll(
        address _owner,
        address _operator,
        bool _approved
    ) internal {
        if (_owner == _operator) {
            revert SelfApproval();
        }
        _operatorApprovals[_owner][_operator] = _approved;
        emit ApprovalForAll(_owner, _operator, _approved);
    }

    function _stake(
        uint16 _numDays,
        uint256 _amount,
        uint256 _shares
    ) internal {
        if (_numDays < MIN_STAKE_DAYS) {
            revert StakeTooShort();
        } else if (_numDays > MAX_STAKE_DAYS) {
            revert StakeTooLong();
        }

        require(maxx.transferFrom(msg.sender, address(this), _amount)); // transfer tokens to this contract -- removed from circulating supply

        totalShares += _shares;
        totalStakesAlltime.increment();
        totalStakesActive.increment();

        uint256 duration = uint256(_numDays) * 1 days * TEST_TIME_FACTOR;

        stakes[idCounter.current()] = StakeData(
            "",
            _amount,
            _shares,
            duration,
            block.timestamp
        );
        endTimes[idCounter.current()] = block.timestamp + duration;
        idCounter.increment();
        emit Stake(msg.sender, _numDays, _amount);
    }

    function _transferStake(uint256 _stakeId, address _to) internal {
        if (_to == address(0)) {
            revert TransferToTheZeroAddress();
        }

        delete _stakeApprovals[_stakeId];

        _owners[_stakeId] = _to;
        emit Transfer(msg.sender, _to);
    }

    function _transfer(address payable _to, uint256 _amount) internal {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    /// @dev Reverts if the `_stakeId` has not been minted yet.
    function _requireStaked(uint256 _stakeId) internal view {
        if (!_exists(_stakeId)) {
            revert StakeDoesNotExist();
        }
    }

    /// @dev Returns whether `_stakeId` exists.
    function _exists(uint256 _stakeId) internal view returns (bool) {
        return _owners[_stakeId] != address(0);
    }

    /// @dev Returns whether `_spender` is allowed to manage `_stakeId`.
    function _isApprovedOrOwner(address _spender, uint256 _stakeId)
        internal
        view
        returns (bool)
    {
        address owner = ownerOf(_stakeId);
        return (_spender == owner ||
            isApprovedForAll(owner, _spender) ||
            getApproved(_stakeId) == _spender);
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
        uint256 bpbBonus = _amount / 10000000;
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
        shareFactor = 1 - (getDaysSinceLaunch() / 3333);
        assert(shareFactor <= 1);
        return shareFactor;
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
