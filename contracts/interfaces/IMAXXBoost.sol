// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title The interface for the Maxx Finance MAXXBoost NFT contract
interface IMAXXBoost is IERC721 {
    function setUsed(uint256 _tokenId) external;

    function getUsedState(uint256 _tokenId) external view returns (bool);
}