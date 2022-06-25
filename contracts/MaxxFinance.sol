// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MaxxFinance is ERC20, ERC20Burnable, Ownable, Pausable {

    /// @notice Tax rate when calling transfer() or transferFrom()
    uint256 public transferTax;
    uint256 public globalDailySellLimit; // TODO: global daily sell limit or transfer limit?
    uint256 public whaleLimit;

    uint256 public burnedAmount;

    /// @notice blacklisted addresses
    mapping(address => bool) public isBlacklisted;

    /// @notice whitelisted addresses
    mapping(address => bool) public isWhitelisted;

    /// @notice The block number of the address's last purchase from a pool
    mapping(address => uint256) public lastPurchase;

    /// @notice Whether the address is a Maxx token pool or not
    mapping(address => bool) public isPool;

    /// @notice The amount of tokens sold each day
    mapping(uint32 => uint256) public dailyAmountSold; // TODO: can be circumvented if new pool is created.

    uint256 public immutable initialTimestamp;

    /// @notice block limited or not
    bool public blockLimited;

    /// @notice The number of blocks required 
    uint256 public blocksBetweenTransfers;

    // blacklisted addresses can receive tokens, but cannot send tokens
    modifier blacklist(address sender) {
        require(
            !isBlacklisted[sender],
            "ERC20: Account is blacklisted from transferring"
        );
        _;
    }

    constructor(address maxxFinanceTreasury, uint256 _transferTax) ERC20("Maxx Finance", "MAXX") {
        _mint(maxxFinanceTreasury, 500000000000 * 10 ** decimals());
        transferTax = _transferTax;
        initialTimestamp = block.timestamp;
    }

    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount) public override blacklist(msg.sender) whenNotPaused returns (bool) {
        require(_amount < whaleLimit, "ERC20: Transfer amount exceeds whale limit");

        uint32 day = uint32(block.timestamp - initialTimestamp / 24 / 60 / 60);
        require(dailyAmountSold[day] + _amount <= globalDailySellLimit, "ERC20: Daily sell limit exceeded");
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isWhitelisted[msg.sender] && lastPurchase[msg.sender] >= block.number - blocksBetweenTransfers) {
            isBlacklisted[msg.sender] = true;
            return false;
        }
        if (isPool[msg.sender]) { // Also occurs if user is withdrawing their liquidity tokens.
            lastPurchase[_to] = block.number;
        } else if (isPool[_to]) {
            dailyAmountSold[day] += _amount;
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
    function transferFrom(address _from, address _to, uint256 _amount) public override blacklist(_from) whenNotPaused returns (bool) {
        require(_amount < whaleLimit, "ERC20: Transfer amount exceeds whale limit"); 

        uint32 day = uint32(block.timestamp - initialTimestamp / 24 / 60 / 60);
        require(dailyAmountSold[day] + _amount <= globalDailySellLimit, "ERC20: Daily sell limit exceeded");
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isWhitelisted[_from] && lastPurchase[_from] >= block.number - blocksBetweenTransfers) {
            isBlacklisted[_from] = true;
            return false;
        }
        if (isPool[_from]) {
            lastPurchase[_to] = block.number;
        } else if (isPool[_to]) {
            dailyAmountSold[day] += _amount;
        }
        if (isPool[_from] || isPool[_to]) {
            _amount = ((_amount * transferTax) / 10000);
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /// @return timestamp The timestamp corresponding to the next day when the global daily sell limit will be reset
    function getNextDayTimestamp() external view returns (uint256 timestamp) {
        uint256 day = ((block.timestamp - initialTimestamp) / 24 / 60 / 60) + 1;
        timestamp = initialTimestamp + (day * 1 days);
    }

    /// @notice add an address to the whitelist
    /// @param _address The pool address
    function addPool(address _address) external onlyOwner {
        isPool[_address] = true;
        isWhitelisted[_address] = true;
    }

    /// @param _transferTax The transfer tax to set
    function setTransferTax(uint256 _transferTax) external onlyOwner {
        require(_transferTax <= 20, "ERC20: Transfer tax must be less than or equal to 20%");
        transferTax = _transferTax;
    }

    /// @param _globalDailySellLimit The new global daily sell limit
    function setGlobalDailySaleLimit(uint256 _globalDailySellLimit) external onlyOwner {
        require(_globalDailySellLimit >= 1000000000 * 10 ** decimals(), "Global daily sell limit must be greater than or equal to 1,000,000,000 tokens");
        globalDailySellLimit = _globalDailySellLimit;
    }

    /// @param _whaleLimit The new whale limit
    function setWhaleLimit(uint256 _whaleLimit) external onlyOwner {
        require(_whaleLimit >= 1000000 * 10 ** decimals(), "Whale limit must be greater than or equal to 1,000,000"); // TODO: confirm whale limit minimum
        whaleLimit = _whaleLimit;
    }

    /// @notice add or remove an address from the whitelist
    /// @param _address The address to add or remove
    /// @param _isWhitelisted Whether to add (true) or remove (false) the address
    function updateWhitelist(address _address, bool _isWhitelisted) external onlyOwner {
        isWhitelisted[_address] = _isWhitelisted;
    }

    /// @notice add or remove an address from the blacklist
    /// @param _address The address to add or remove
    /// @param _isBlacklisted Whether to add (true) or remove (false) the address
    function updateBlacklist(address _address, bool _isBlacklisted) external onlyOwner {
        isBlacklisted[_address] = _isBlacklisted;
    }

    /// @notice Update the blocks required between transfers
    /// @param _blocksBetweenTransfers The number of blocks required between transfers
    function updateBlocksBetweenTransfers(uint256 _blocksBetweenTransfers) external onlyOwner {
        require(_blocksBetweenTransfers <= 5, "Blocks between transfers must be less than or equal to 5");
        blocksBetweenTransfers = _blocksBetweenTransfers;
    }

    /// @notice Update blockLimited
    /// @param _blockLimited Whether to block limit or not
    function updateBlockLimited(bool _blockLimited) external onlyOwner {
        blockLimited = _blockLimited;
    }
}