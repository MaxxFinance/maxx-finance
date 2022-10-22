// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {IStake} from "./interfaces/IStake.sol";
import {IFreeClaim} from "./interfaces/IFreeClaim.sol";

/// @title Maxx Finance Free Claim
/// @author Alta Web3 Labs - SonOfMosiah
contract FreeClaim is IFreeClaim, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    struct Claim {
        address user;
        uint256 amount;
        uint256 shares;
        uint256 stakeId;
        uint256 timestamp;
    }

    /// @notice Merkle root for the free claim whitelist
    bytes32 public merkleRoot;

    /// @notice Free claim start date
    uint256 public launchDate;
    uint256 public constant FREE_CLAIM_DURATION = 365 days;

    /// @notice Max number of MAXX tokens that can be claimed by a user
    uint256 public constant MAX_CLAIM_AMOUNT = 1_000_000 * (1e18); // 1 million MAXX

    /// @notice MAXX token contract
    IERC20 public maxx;

    /// @notice MAXX staking contract
    IStake public maxxStake;

    /// @notice Mapping of claims by user address
    mapping(address => Claim[]) public userClaims;
    mapping(address => uint256[]) public userFreeReferral;

    /// @notice True if user has already claimed MAXX
    mapping(address => bool) public hasClaimed;

    /// @notice Mapping claims to owners
    mapping(address => uint256) public claimOwners;

    /// @notice Mapping of claims
    mapping(uint256 => Claim) public claims;

    /// Array of ids for staked claims
    uint256[] public stakedClaims;
    /// Array of ids for unstaked claims;
    uint256[] public unstakedClaims;

    uint256 public remainingBalance;
    uint256 public maxxAllocation;

    uint256 public claimedAmount;

    /// @notice Claim Counter
    Counters.Counter public claimCounter;

    constructor() {
        _transferOwnership(tx.origin);
    }

    /// @notice Function to retrive free claim
    /// @param _amount The amount of MAXX whitelisted for the sender
    /// @param _proof The merkle proof of the whitelist
    function freeClaim(
        uint256 _amount,
        bytes32[] memory _proof,
        address _referrer
    ) external nonReentrant {
        if (remainingBalance == 0) {
            revert FreeClaimEnded();
        }
        if (_referrer == msg.sender) {
            revert SelfReferral();
        }
        if (
            !_verifyMerkleLeaf(_generateMerkleLeaf(msg.sender, _amount), _proof)
        ) {
            revert InvalidProof();
        }
        if (hasClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        hasClaimed[msg.sender] = true;

        if (_amount > MAX_CLAIM_AMOUNT) {
            _amount = MAX_CLAIM_AMOUNT; // cannot claim more than the MAX_CLAIM_AMOUNT
        }
        uint256 timePassed;
        if (block.timestamp < launchDate) {
            revert FreeClaimNotStarted();
        }
        unchecked {
            timePassed = block.timestamp - launchDate;
        }

        _amount =
            (_amount * (FREE_CLAIM_DURATION - timePassed)) /
            FREE_CLAIM_DURATION; // adjust amount for the speed penalty

        bool stake;
        if (
            address(maxxStake) != address(0) &&
            maxxStake.launchDate() < block.timestamp
        ) {
            stake = true;
        }
        _claim(_amount, _referrer, stake);
    }

    /// @notice Add MAXX to the free claim allocation
    /// @param _amount The amount of MAXX to add to the free claim allocation
    function allocateMaxx(uint256 _amount) external onlyOwner {
        if (!maxx.transferFrom(msg.sender, address(this), _amount)) {
            revert MaxxAllocationFailed();
        }
        maxxAllocation += _amount;
        remainingBalance = maxx.balanceOf(address(this));
    }

    /// @notice Set the Maxx Finance Staking contract
    /// @param _maxxStake The Maxx Finance Staking contract
    function setMaxxStake(address _maxxStake) external onlyOwner {
        maxxStake = IStake(_maxxStake);
        maxx.approve(_maxxStake, type(uint256).max);
    }

    /// @notice Function to update the launch date
    /// @dev Launch date must be set to UTC 00:00:00 to work properly with the front end
    /// @param _launchDate The new launch date
    function updateLaunchDate(uint256 _launchDate) external onlyOwner {
        if (
            (launchDate != uint256(0) && block.timestamp >= launchDate) ||
            block.timestamp >= _launchDate
        ) {
            revert LaunchDateUpdateFailed();
        }
        launchDate = _launchDate;
        emit LaunchDateUpdated(_launchDate);
    }

    /// @notice Function to set the MAXX token address
    /// @param _maxx The maxx token contract address
    function setMaxx(address _maxx) external onlyOwner {
        if (_maxx == address(0)) {
            revert InvalidMaxxAddress();
        }
        maxx = IERC20(_maxx);
        emit MaxxSet(_maxx);
    }

    /// @notice Add a new merkle root
    /// @dev Emits a MerkleRootSet event
    /// @param _merkleRoot new merkle root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        if (_merkleRoot == bytes32(0)) {
            revert InvalidMerkleRoot();
        }
        merkleRoot = _merkleRoot;
        emit MerkleRootSet(_merkleRoot);
    }

    function stakeClaim(uint256 _unstakedClaimId, uint256 _claimId) external {
        if (msg.sender != address(maxxStake) || msg.sender == address(0)) {
            revert OnlyMaxxStake();
        }
        Claim storage claim = claims[_claimId];
        stakedClaims.push(_claimId);
        (uint256 stakeId, uint256 shares) = maxxStake.freeClaimStake(
            claim.user,
            365,
            claim.amount
        );
        claim.stakeId = stakeId;
        claim.shares = shares;
        delete unstakedClaims[_unstakedClaimId];
    }

    /// @notice Get the number of total claimers
    /// @return The number of total claimers
    function getTotalClaimers() external view returns (uint256) {
        return stakedClaims.length + unstakedClaims.length;
    }

    /// @notice Get all unstaked claims
    /// @return The array of unstaked claim ids
    function getAllUnstakedClaims() external view returns (uint256[] memory) {
        return unstakedClaims;
    }

    /// @notice Get the unstaked claims slice from `_start` to `_end`
    /// @param _start The start index
    /// @param _end The end index
    /// @return The array of unstaked claim ids
    function getUnstakedClaimsSlice(uint256 _start, uint256 _end)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory slice = new uint256[](_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            slice[i - _start] = unstakedClaims[i];
        }
        return slice;
    }

    /// @notice Get the referrals by user
    /// @param _user The user to get the referrals for
    /// @return The referrals for _user
    function getUserFreeReferrals(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userFreeReferral[_user];
    }

    /// @notice Get the claims by user
    /// @param _user The user to get the claims for
    /// @return The claims for _user
    function getUserClaims(address _user)
        external
        view
        returns (Claim[] memory)
    {
        return userClaims[_user];
    }

    /// @param _account The account presumed to be in the merkle tree
    /// @param _amount The amount of MAXX available for the account to claim
    /// @param _proof The merkle proof of the account
    /// @return Whether the account is in the merkle tree
    function verifyMerkleLeaf(
        address _account,
        uint256 _amount,
        bytes32[] memory _proof
    ) external view returns (bool) {
        return
            _verifyMerkleLeaf(_generateMerkleLeaf(_account, _amount), _proof);
    }

    function _claim(
        uint256 _amount,
        address _referrer,
        bool stake
    ) internal {
        if (_amount <= remainingBalance) {
            if (_referrer != address(0)) {
                _referralClaim(_amount, _referrer, stake);
                _amount += _amount / 10;
            }
        } else {
            _amount = remainingBalance;
        }

        remainingBalance -= _amount;
        claimedAmount += _amount;
        uint256 stakeId;
        uint256 shares;
        if (stake) {
            stakedClaims.push(claimCounter.current());
            (stakeId, shares) = maxxStake.freeClaimStake(
                msg.sender,
                365,
                _amount
            );
        } else {
            unstakedClaims.push(claimCounter.current());
        }

        Claim memory userClaim = Claim({
            user: msg.sender,
            amount: _amount,
            shares: shares,
            stakeId: stakeId,
            timestamp: block.timestamp
        });
        claims[claimCounter.current()] = userClaim;
        userClaims[msg.sender].push(userClaim);

        claimCounter.increment();
        emit UserClaim(msg.sender, _amount);
    }

    function _referralClaim(
        uint256 _amount,
        address _referrer,
        bool stake
    ) internal {
        uint256 referralAmount = _amount / 10; // referrer receives 10% of claim amount as bonus

        userFreeReferral[_referrer].push(block.timestamp);
        userFreeReferral[_referrer].push(_amount);
        userFreeReferral[_referrer].push(referralAmount);

        _amount += referralAmount; // +10% bonus for referral
        remainingBalance -= referralAmount;
        claimedAmount += referralAmount;

        uint256 stakeId;
        uint256 shares;

        if (stake) {
            stakedClaims.push(claimCounter.current());
            (stakeId, shares) = maxxStake.freeClaimStake(
                _referrer,
                14,
                referralAmount
            );
        } else {
            unstakedClaims.push(claimCounter.current());
        }

        Claim memory referralClaim = Claim({
            user: msg.sender,
            amount: referralAmount,
            shares: shares,
            stakeId: stakeId,
            timestamp: block.timestamp
        });
        claims[claimCounter.current()] = referralClaim;
        userClaims[_referrer].push(referralClaim);

        claimCounter.increment();
        emit UserClaim(_referrer, referralAmount);
        emit Referral(_referrer, msg.sender, referralAmount);
    }

    function _verifyMerkleLeaf(bytes32 _leafNode, bytes32[] memory _proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(_proof, merkleRoot, _leafNode);
    }

    function _generateMerkleLeaf(address _account, uint256 _amount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_account, _amount));
    }
}
