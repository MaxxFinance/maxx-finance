// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MaxxFinance is ERC20, ERC20Burnable, Ownable {

    /// @notice Tax rate when calling transfer() or transferFrom()
    uint256 public TRANSFER_TAX;
    uint256 public GLOBAL_DAILY_SELL_LIMIT;
    uint256 public WHALE_LIMIT;

    uint256 public burnedAmount;

    // --- { Start Axion variable section } ---

    /// @dev addresses blacklist if attempt to buy and sell in same block or consecutive blocks
    mapping(address => bool) public blacklist;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public timeOfLastTransfer;
    bool public timeLimited;
    mapping(address => bool) public isPool;
    mapping(address => bool) public routers;
    uint256 public timeBetweenTransfers;

    // --- { End Axion variable section } ---

    // Black list for bots */
    modifier isBlackedListed(address sender, address recipient) {
        require(
            blacklist[sender] == false,
            'ERC20: Account is blacklisted from transferring'
        );
        _;
    }

    constructor(address maxxFinanceTreasury) ERC20("Maxx Finance", "MAXX") {
        _mint(maxxFinanceTreasury, 500000000000 * 10 ** decimals());
    }

    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        if (isPool[_to]) {
            _amount = ((_amount * TRANSFER_TAX) / 10000);
        }
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax on lp pools
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        if (isPool[_from] || isPool[_to]) {
            _amount = ((_amount * TRANSFER_TAX) / 10000);
        }
        return super.transferFrom(_from, _to, _amount);
    }

    // protection
    // comes from Axion
    function isTimeLimited(address sender, address recipient) internal {
        if (
            timeLimited &&
            whitelist[recipient] == false &&
            whitelist[sender] == false
        ) {
            address toDisable = sender;
            if (isPool[sender] == true) {
                toDisable = recipient;
            } else if (isPool[recipient] == true) {
                toDisable = sender;
            }

            if (
                isPool[toDisable] == true ||
                routers[toDisable] == true ||
                toDisable == address(0)
            ) return; // Do nothing as we don't want to disable router

            if (timeOfLastTransfer[toDisable] == 0) {
                timeOfLastTransfer[toDisable] = block.timestamp;
            } else {
                require(
                    block.timestamp - timeOfLastTransfer[toDisable] >
                        timeBetweenTransfers,
                    'ERC20: Time since last transfer must be greater then time to transfer'
                );
                timeOfLastTransfer[toDisable] = block.timestamp;
            }
        }
    }
}