// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title The interface for the Maxx Finance token contract
interface IMaxxFinance is IERC20 {
    function mint() external;
    function burn() external;
    function burnFrom() external;

    // Functions from IERC20.sol
    // totalSupply()
    // balanceOf()
    // transfer()
    // allowance()
    // approve()
    // transferFrom()
}