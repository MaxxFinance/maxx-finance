// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

/// The Maxx Finance Staking contract hasn't been initialized
error StakingNotInitialized();

/// Only the Staking contract can call this function
error OnlyMaxxStake();

/// @title Maxx Finance Free Claim
/// @author Alta Web3 Labs - SonOfMosiah
contract FreeClaim is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Claim {
        address user;
        uint256 amount;
    }

    /// Merkle root for the free claim whitelist
    bytes32 public merkleRoot; // TODO: may need to create multiple merkle roots depending on Merkle Tree size.

    /// Free claim start date
    uint256 public immutable launchDate;
    uint256 public constant FREE_CLAIM_DURATION = 365 days;

    /// Max number of MAXX tokens that can be claimed by a user
    uint256 public constant MAX_CLAIM_AMOUNT = 1000000 * (10**8); // 1 million MAXX

    /// MAXX token contract
    IERC20 public maxx;

    /// MAXX staking contract
    IStake public maxxStake;

    /// True if user has already claimed MAXX
    mapping(address => bool) public hasClaimed;

    /// Mapping claims to owners
    mapping(address => uint256) public claimOwners;
    /// Array of staked claims
    Claim[] public stakedClaims;
    /// Array of unstaked claims;
    Claim[] public unstakedClaims;

    uint256 public remainingBalance;
    uint256 public maxxAllocation;

    uint256 public claimedAmount;

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

    constructor(uint256 _launchDate, address _maxx) {
        launchDate = _launchDate;
        maxx = IERC20(_maxx);
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

        if (remainingBalance == 0) {
            revert FreeClaimEnded();
        }

        if (_amount > MAX_CLAIM_AMOUNT) {
            _amount = MAX_CLAIM_AMOUNT; // cannot claim more than the MAX_CLAIM_AMOUNT
        }
        // solhint-disable-next-line not-rely-on-time
        uint256 timePassed = block.timestamp - launchDate;

        _amount =
            (_amount * (FREE_CLAIM_DURATION - timePassed)) /
            FREE_CLAIM_DURATION; // adjust amount for the speed penalty

        if (
            address(maxxStake) != address(0) &&
            // solhint-disable-next-line not-rely-on-time
            maxxStake.launchDate() < block.timestamp
        ) {
            if (_amount > remainingBalance) {
                // No referral bonus if contract balance is less than the amount to claim
                _amount = remainingBalance;

                stakedClaims.push(Claim(msg.sender, _amount));
                claimedAmount += _amount;
                emit UserClaim(msg.sender, _amount);
            } else {
                if (_referrer != address(0)) {
                    uint256 referralAmount = _amount / 10;
                    _amount += referralAmount; // +10% bonus for referral
                    stakedClaims.push(Claim(_referrer, referralAmount));
                    claimedAmount += referralAmount;
                    emit UserClaim(_referrer, referralAmount);
                    emit Referral(_referrer, msg.sender, referralAmount);
                }

                hasClaimed[msg.sender] = true;

                stakedClaims.push(Claim(msg.sender, _amount));
                claimedAmount += _amount;
                emit UserClaim(msg.sender, _amount);
            }
        } else {
            if (_amount > remainingBalance) {
                // No referral bonus if contract balance is less than the amount to claim
                _amount = remainingBalance;

                unstakedClaims.push(Claim(msg.sender, _amount));
                claimedAmount += _amount;
                emit UserClaim(msg.sender, _amount);
            } else {
                if (_referrer != address(0)) {
                    uint256 referralAmount = _amount / 10;
                    _amount += referralAmount; // +10% bonus for referral
                    unstakedClaims.push(Claim(_referrer, referralAmount));
                    claimedAmount += referralAmount;
                    emit UserClaim(_referrer, referralAmount);
                    emit Referral(_referrer, msg.sender, referralAmount);
                }

                hasClaimed[msg.sender] = true;

                stakedClaims.push(Claim(msg.sender, _amount));
                claimedAmount += _amount;
                emit UserClaim(msg.sender, _amount);
            }
        }
    }

    /// @notice Add MAXX to the free claim allocation
    /// @param _amount The amount of MAXX to add to the free claim allocation
    function allocateMaxx(uint256 _amount) external onlyOwner {
        maxx.transferFrom(msg.sender, address(this), _amount);
        maxxAllocation += _amount;
    }

    /// @notice Set the Maxx Finance Staking contract
    /// @param _maxxStake The Maxx Finance Staking contract
    function setMaxxStake(address _maxxStake) external onlyOwner {
        maxxStake = IStake(_maxxStake);
    }

    /// @notice Set the merkle root
    /// @param _merkleRoot new merkle root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    /// @notice Stake the unstaked claims
    function stakeClaims() external {
        if (msg.sender != address(maxxStake) || msg.sender == address(0)) {
            revert OnlyMaxxStake();
        }

        for (uint256 i = 0; i < unstakedClaims.length; i++) {
            stakedClaims.push(unstakedClaims[i]);
        }
        delete unstakedClaims;
    }

    /// @notice Get the number of total claimers
    /// @return The number of total claimers
    function getTotalClaimers() external view returns (uint256) {
        return stakedClaims.length + unstakedClaims.length;
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
