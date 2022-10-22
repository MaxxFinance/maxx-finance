// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILiquidityAmplifier.sol";

/// @title MAXX Genesis NFT Collection
/// @author Andrei Toma
/// @notice Using a Code from the MAXX Gleam campaign can land you one of these NFTs and a 5% bonus in the Amplifier Allocation. Codes can be only used one time.
contract MAXXGenesis is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    // The maximum supply of the collection
    uint256 public constant MAX_SUPPLY = 5000;

    // Token URI for the NFTs available to use for Staking APR Bonus
    string internal constant AVAILABLE_URI = "available";

    // Token URI for used NFTs
    string internal constant USED_URI = "used";

    // The address of the MAXX Liquidity Amplifier Smart Contract
    address public immutable amplifierContract;

    // The address of the MAXX Staking Smart Contract
    address public immutable stakingContract;

    // Mapping of Token ID to used state
    mapping(uint256 => bool) private usedState;

    // Mapping of hashed codes to their availability
    mapping(bytes32 => bool) codes;

    /// @notice Sets the Name and Ticker for the Collection
    constructor(address _amplifierContract, address _stakingContract)
        ERC721("MAXXGenesis", "MAXXG")
    {
        amplifierContract = _amplifierContract;
        stakingContract = _stakingContract;
    }

    /// @notice Called by MAXX Staking SC to mint a reward NFT to user that stake >= 10.000.000 MAXX for 3.333 days.
    /// @param _code the code required to redeem the NFT
    /// @param _user the user address to mint to
    /// @dev supply.increment() is called before _safeMint() to start the collection at tokenId 1
    /// @return bool returns true if minting conditions are meet and NFT is minted, else returns false.
    function mint(string memory _code, address _user) external returns (bool) {
        require(
            msg.sender == amplifierContract,
            "Only the Liquidity Amplifier contract can call this fuction!"
        );
        bytes32 hashedCode = keccak256(abi.encodePacked(_code));
        bool codeAvailable = codes[hashedCode];
        bool supplyAvailable = supply.current() + 1 <= MAX_SUPPLY;
        if (codeAvailable && supplyAvailable) {
            codes[hashedCode] = false;
            supply.increment();
            _safeMint(_user, supply.current());
            return true;
        } else {
            return false;
        }
    }

    /// @notice Set the hashed codes that can be used to mint an NFT
    /// @param _codes Array of hashed codes
    function setCodes(bytes32[] calldata _codes) external onlyOwner {
        uint256 _length = _codes.length;
        for (uint256 i; i < _length; i++) {
            codes[_codes[i]] = true;
        }
    }

    /// @notice Marks NFT as used after it has been used in the MAXX Staking Contract
    /// @param _tokenId the Token ID of the NFT to be marked as used
    /// @dev This function is only callable by the MAXX Staking Contract
    function setUsed(uint256 _tokenId) external {
        require(
            msg.sender == stakingContract,
            "Only the Staking Contract can set a token as used"
        );
        usedState[_tokenId] = true;
    }

    /// @notice Verifies if a NFT is used or not
    /// @param _tokenId the Token ID that is verified
    /// @return Bool for the used state of the NFT
    function getUsedState(uint256 _tokenId) external view returns (bool) {
        return usedState[_tokenId];
    }

    /// @notice Returns the Token IDs of the NFTs owner by a user
    /// @param _owner the address of the user
    /// @return ownedTokenIds The Token IDs owned by the address
    function tokensOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex;
        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= MAX_SUPPLY
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);
            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }
            currentTokenId++;
        }
        return ownedTokenIds;
    }

    /// @notice Returns the URI used to access the IPFS file containing the NFT Metadata
    /// @param _tokenId the Token ID of the NFT
    /// @return The URI for the Token ID
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (usedState[_tokenId]) {
            return USED_URI;
        } else {
            return AVAILABLE_URI;
        }
    }

    /// @notice Returns the total supply of the collection
    function totalSupply() public view returns (uint256) {
        return supply.current();
    }
}
