// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { IStake } from "./interfaces/IStake.sol";

error AlreadyClaimed();
error InvalidProof();
error FreeClaimEnded();

/// @author Alta Web3 Labs - SonOfMosiah
contract FreeClaim is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Emitted when free claim is claimed
    /// @param user The user claiming free claim
    /// @param amount The amount of free claim claimed
    event UserClaim(address indexed user, uint256 amount);

    // TODO: may need to create multiple merkle roots depending on Merkle Tree size.
    /// @notice Merkle root for the free claim whitelist
    bytes32 public merkleRoot;

    uint256 public immutable startDate;
    uint256 constant FREE_CLAIM_DURATION = 365 days;

    /// @notice Max number of MAXX tokens that can be claimed by a user
    uint256 constant public MAX_CLAIM_AMOUNT = 1000000 * (10 ** 8); // 1 million MAXX

    /// @notice Address of the MAXX staking contract
    IStake public stake;

    /// @notice Address of the MAXX token contract
    IERC20 public MAXX;

    /// @notice True if user has already claimed MAXX
    mapping (address => bool) public hasClaimed;

    constructor(uint256 _startDate, bytes32 _merkleRoot, address _stake, address _MAXX) {
        startDate = _startDate;
        merkleRoot = _merkleRoot;
        stake = IStake(_stake);
        MAXX = IERC20(_MAXX);
    }

    struct Claim {
        address user;
        uint256 amount;
    }

    Claim[] public claims;

    /// @notice Function to retrive free claim
    /// @param _amount The amount of MAXX whitelisted for the sender
    /// @param _proof The merkle proof of the whitelist
    function freeClaim(uint256 _amount, bytes32[] memory _proof, address _referrer) external nonReentrant {
        if (hasClaimed[_referrer]) {
            revert AlreadyClaimed();
        }
        if (!_verifyMerkleLeaf(_generateMerkleLeaf(msg.sender, _amount), _proof)) {
            revert InvalidProof();
        }

        uint256 contractBalance = MAXX.balanceOf(address(this));
        if (contractBalance == 0) {
            revert FreeClaimEnded();
        }

        uint256 timePassed = block.timestamp - startDate;

        if (_amount > contractBalance) {
            _amount = contractBalance;
        }

        if (_amount > MAX_CLAIM_AMOUNT) {
            _amount = MAX_CLAIM_AMOUNT; // cannot claim more than the MAX_CLAIM_AMOUNT
        }

         _amount = _amount * (FREE_CLAIM_DURATION - timePassed) / FREE_CLAIM_DURATION; // adjust amount for the speed penalty

        if (_referrer != address(0)) {
            uint256 referralAmount = _amount / 10;
            _amount += referralAmount;
            stake.freeClaimStake(_referrer, referralAmount); // give the referrer 10% of the free claim amount
            emit UserClaim(_referrer, referralAmount);
        }
       
        hasClaimed[msg.sender] = true;

        stake.freeClaimStake(msg.sender, _amount);
        emit UserClaim(msg.sender, _amount);
    }

    /// @param _account The account presumed to be in the merkle tree
    /// @param _amount The amount of MAXX available for the account to claim
    /// @param _proof The merkle proof of the account
    /// @return Whether the account is in the merkle tree
    function verifyMerkleLeaf(address _account, uint256 _amount, bytes32[] memory _proof)
        external
        view
        returns (bool)
    {
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