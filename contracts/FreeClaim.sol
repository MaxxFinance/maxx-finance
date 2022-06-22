// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { MaxxStake as Stake } from './MaxxStake.sol';

/// @author Alta Web3 Labs
contract FreeClaim is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Merkle root for the free claim whitelist
    bytes32 public merkleRoot;

    /// @notice Max number of MAXX tokens that can be claimed by a user
    uint256 constant public MAX_CLAIM_AMOUNT = 5000000 * (10 ** 8); // 5 million MAXX

    /// @notice Address of the MAXX staking contract
    Stake public stake;

    /// @notice Address of the MAXX token contract
    IERC20 public MAXX;

    /// @notice True if user has already claimed MAXX
    mapping (address => bool) public hasClaimed;

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    struct Claim {
        address user;
        uint256 amount;
    }

    mapping (address => uint256) public userToClaim;
    Claim[] public claims;

    /// @param _amount The amount of MAXX whitelisted for the sender
    /// @param _proof The merkle proof of the whitelist
    function freeClaim(uint256 _amount, bytes32[] memory _proof, address _referrer) public nonReentrant {
        require(!hasClaimed[msg.sender], "User has already claimed");
        require(
            _verifyMerkleLeaf(_generateMerkleLeaf(msg.sender, _amount), _proof),
            "Invalid proof, not on whitelist"
        );

        uint256 contractBalance = MAXX.balanceOf(address(this));
        require(contractBalance > 0, "No MAXX tokens to claim");
        if (_amount > contractBalance) {
            _amount = contractBalance;
        }

        if (_referrer != address(0)) {
            _amount = ((_amount * 11) / 10); // Should be moved after the following if statement if referral bonus can exceed max claim amount
        }

        if (_amount > MAX_CLAIM_AMOUNT) {
            _amount = MAX_CLAIM_AMOUNT; // cannot claim more than the MAX_CLAIM_AMOUNT
        }

        hasClaimed[msg.sender] = true;

        if (userToClaim[msg.sender] == 0) {
            claims.push(Claim(msg.sender, _amount));
        } else {
            claims[userToClaim[msg.sender]].amount += _amount;
        }

        if (_referrer != address(0)) {
            if (userToClaim[_referrer] == 0) {
            claims.push(Claim(_referrer, _amount));
            } else {
                claims[userToClaim[_referrer]].amount += _amount;
            }
        }
    }

    /// @param _account The account presumed to be in the merkle tree
    /// @param _amount The amount of MAXX available for the account to claim
    /// @param _proof The merkle proof of the account
    /// @return Whether the account is in the merkle tree
    function verifyMerkleLeaf(address _account, uint256 _amount, bytes32[] memory _proof)
        public
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