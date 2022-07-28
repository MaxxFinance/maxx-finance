// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title The interface for the Maxx Finance token contract
interface IMaxxFinance is IERC20 {
    /// @notice Increases the token balance of `to` by `amount`
    /// @param to The address to mint to
    /// @param amount The amount to mint
    /// Emits a {Transfer} event.
    function mint(address to, uint256 amount) external;

    /// @dev Decreases the token balance of `msg.sender` by `amount`
    /// @param amount The amount to burn
    /// Emits a {Transfer} event with `to` set to the zero address.
    function burn(uint256 amount) external;

    /// @dev Decreases the token balance of `from` by `amount`
    /// @param from The address to burn from
    /// @param amount The amount to burn
    /// Emits a {Transfer} event with `to` set to the zero address.
    function burnFrom(address from, uint256 amount) external;
}
