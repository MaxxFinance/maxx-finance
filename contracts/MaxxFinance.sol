// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MaxxFinance is ERC20, ERC20Burnable, Ownable {

    /// @notice Tax rate when calling transfer() or transferFrom()
    uint256 public transferTax;
    uint256 public GLOBAL_DAILY_SELL_LIMIT;
    uint256 public WHALE_LIMIT;

    uint256 public burnedAmount;

    /// @notice blacklisted addresses
    mapping(address => bool) public isBlacklisted;

    /// @notice whitelisted addresses
    mapping(address => bool) public isWhitelisted;

    /// @notice The block number of the address's last purchase from a pool
    mapping(address => uint256) public lastPurchase;

    /// @notice Whether the address is a Maxx token pool or not
    mapping(address => bool) public isPool;

    /// @notice block limited or not
    bool public blockLimited;

    /// @notice The number of blocks required 
    uint256 public blocksBetweenTransfers;

    // blacklisted addresses can receive tokens, but cannot send tokens
    modifier blacklist(address sender) {
        require(
            isBlacklisted[sender] == false,
            "ERC20: Account is blacklisted from transferring"
        );
        _;
    }

    constructor(address maxxFinanceTreasury, uint256 _transferTax) ERC20("Maxx Finance", "MAXX") {
        _mint(maxxFinanceTreasury, 500000000000 * 10 ** decimals());
        transferTax = _transferTax;
    }

    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // /// @dev Overrides the decimals() function to return 18
    // /// @return The number of decimals
    // function decimals() public pure override returns (uint8) {
    //     return 8; // 8 decimals
    // }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount) public override blacklist(msg.sender) returns (bool) {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isWhitelisted[msg.sender] && lastPurchase[msg.sender] >= block.number - blocksBetweenTransfers) {
            isBlacklisted[msg.sender] = true;
            return false;
        }
        if (isPool[msg.sender]) {
            lastPurchase[_to] = block.number;
        }
        if (isPool[_to] || isPool[msg.sender]) {
            _amount = ((_amount * transferTax) / 10000);
        }
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax on lp pools
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public override blacklist(_from) returns (bool) {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isWhitelisted[_from] && lastPurchase[_from] >= block.number - blocksBetweenTransfers) {
            isBlacklisted[_from] = true;
            return false;
        }
        if (isPool[_from]) {
            lastPurchase[_to] = block.number;
        }
        if (isPool[_from] || isPool[_to]) {
            _amount = ((_amount * transferTax) / 10000);
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /// @notice add an address to the whitelist
    /// @param _address The pool address
    function addPool(address _address) public onlyOwner {
        isPool[_address] = true;
        isWhitelisted[_address] = true;
    }

    /// @notice add or remove an address from the whitelist
    /// @param _address The address to add or remove
    /// @param _isWhitelisted Whether to add (true) or remove (false) the address
    function updateWhitelist(address _address, bool _isWhitelisted) public onlyOwner {
        isWhitelisted[_address] = _isWhitelisted;
    }

    /// @notice add or remove an address from the blacklist
    /// @param _address The address to add or remove
    /// @param _isBlacklisted Whether to add (true) or remove (false) the address
    function updateBlacklist(address _address, bool _isBlacklisted) public onlyOwner {
        isBlacklisted[_address] = _isBlacklisted;
    }

    /// @notice Update the blocks required between transfers
    /// @param _blocksBetweenTransfers The number of blocks required between transfers
    function updateBlocksBetweenTransfers(uint256 _blocksBetweenTransfers) public onlyOwner {
        require(_blocksBetweenTransfers <= 5, "Blocks between transfers too high");
        blocksBetweenTransfers = _blocksBetweenTransfers;
    }

    /// @notice Update blockLimited
    /// @param _blockLimited Whether to block limit or not
    function updateBlockLimited(bool _blockLimited) public onlyOwner {
        blockLimited = _blockLimited;
    }
}