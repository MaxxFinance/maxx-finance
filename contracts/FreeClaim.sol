// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IStake} from "./interfaces/IStake.sol";

/// User has already claimed their allotment of MAXX
error AlreadyClaimed();

/// Merkle proof is invalid
error InvalidProof();

/// No more MAXX left to claim
error FreeClaimEnded();

/// User cannot refer themselves
error SelfReferral();

// /// The Maxx Finance Staking contract hasn't been initialized
// error StakingNotInitialized();

// TODO: discuss staking contract initialization
/// @title Maxx Finance Free Claim
/// @author Alta Web3 Labs - SonOfMosiah
contract FreeClaim is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    // /// @notice Emitted when claim is staked
    // /// @param user The user staking the claim
    // /// @param amount The amount of claim staked
    // event StakeClaim(address indexed user, uint256 amount);

    // TODO: may need to create multiple merkle roots depending on Merkle Tree size.
    /// Merkle root for the free claim whitelist
    bytes32 public merkleRoot;

    /// Free claim start date
    uint256 public immutable startDate;
    uint256 constant FREE_CLAIM_DURATION = 365 days;

    /// Max number of MAXX tokens that can be claimed by a user
    uint256 public constant MAX_CLAIM_AMOUNT = 1000000 * (10**8); // 1 million MAXX

    /// Maxx Finance staking contract
    IStake public stake;

    /// MAXX token contract
    IERC20 public MAXX;

    /// True if user has already claimed MAXX
    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public hasStaked;

    /// Mapping users to their claim amounts
    mapping(address => uint256) public claims;
    uint256 private claimedAmount;

    constructor(
        uint256 _startDate,
        bytes32 _merkleRoot,
        address _MAXX
    ) {
        startDate = _startDate;
        merkleRoot = _merkleRoot;
        MAXX = IERC20(_MAXX);
    }

    struct Claim {
        address user;
        uint256 amount;
    }

    /// @notice Function to retrive free claim
    /// @param _amount The amount of MAXX whitelisted for the sender
    /// @param _proof The merkle proof of the whitelist
    function freeClaim(
        uint256 _amount,
        bytes32[] memory _proof,
        address _referrer
    ) external nonReentrant {
        if (_referrer == msg.sender) {
            revert SelfReferral();
        }
        if (hasClaimed[_referrer]) {
            revert AlreadyClaimed();
        }
        if (
            !_verifyMerkleLeaf(_generateMerkleLeaf(msg.sender, _amount), _proof)
        ) {
            revert InvalidProof();
        }

        uint256 contractBalance = MAXX.balanceOf(address(this));
        if (contractBalance == 0) {
            revert FreeClaimEnded();
        }

        if (_amount > MAX_CLAIM_AMOUNT) {
            _amount = MAX_CLAIM_AMOUNT; // cannot claim more than the MAX_CLAIM_AMOUNT
        }

        uint256 timePassed = block.timestamp - startDate;

        _amount =
            (_amount * (FREE_CLAIM_DURATION - timePassed)) /
            FREE_CLAIM_DURATION; // adjust amount for the speed penalty

        if (_amount > contractBalance) {
            // No referral bonus if contract balance is less than the amount to claim
            _amount = contractBalance;

            claims[msg.sender] += _amount;
            claimedAmount += _amount;
            emit UserClaim(msg.sender, _amount);
        } else {
            if (_referrer != address(0)) {
                uint256 referralAmount = _amount / 10;
                _amount += referralAmount; // +10% bonus for referral
                claims[_referrer] += referralAmount;
                claimedAmount += referralAmount;
                emit UserClaim(_referrer, referralAmount);
                emit Referral(_referrer, msg.sender, referralAmount);
            }

            hasClaimed[msg.sender] = true;

            claims[msg.sender] += _amount;
            claimedAmount += _amount;
            emit UserClaim(msg.sender, _amount);
        }
    }

    /// @notice Function to stake free claim
    function stakeClaim() external {
        if (address(stake == address(0))) {
            revert StakingNotInitialized();
        }
        uint256 claimAmount = claims[msg.sender].amount; // retrieve user's claim from storage
        stake.freeClaimStake(msg.sender, claimAmount);
        emit StakeClaim(msg.sender, claimAmount);
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
            MerkleProof.verify(
                _proof,
                merkleRoot,
                _generateMerkleLeaf(_account, _amount)
            );
    }

    /// @notice Update the merkle root
    /// @param _merkleRoot new merkle root
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /// @notice Function to set the Maxx Finance staking contract address
    /// @param _stake Address of the Maxx Finance staking contract
    function setStakeAddress(address _stake) external onlyOwner {
        stake = IStake(_stake);
    }

    function _generateMerkleLeaf(address _account, uint256 _amount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_account, _amount));
    }

    function _verifyMerkleLeaf(bytes32 _leafNode, bytes32[] memory _proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(_proof, merkleRoot, _leafNode);
    }
}
