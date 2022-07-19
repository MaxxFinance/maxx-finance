// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

contract MaxxFinanceTest is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Tax rate when calling transfer() or transferFrom()
    uint256 public transferTax; // 1000 = 10%
    uint256 constant TRANSFER_TAX_FACTOR = 10000;

    /// @notice Global daily sell limit
    uint256 public globalDailySellLimit; // TODO: global daily sell limit or transfer limit?
    uint256 constant GLOBAL_DAILY_SELL_LIMIT_MINIMUM = 1000000000; // 1 billion TODO: confirm desired amount

    /// @notice Whale limit
    uint256 public whaleLimit;
    uint256 constant WHALE_LIMIT_MINIMUM = 1000000; // 1 million TODO: confirm desired amount

    uint256 public burnedAmount; // TODO: track the burnedAmounts from the transfer tax

    /// @notice blacklisted addresses
    mapping(address => bool) public isBlocked;

    /// @notice whitelisted addresses
    mapping(address => bool) public isAllowed;

    /// @notice The block number of the address's last purchase from a pool
    mapping(address => uint256) public lastPurchase;

    /// @notice Whether the address is a Maxx token pool or not
    mapping(address => bool) public isPool;

    /// @notice The amount of tokens sold each day
    mapping(uint32 => uint256) public dailyAmountSold; // TODO: can be circumvented if new pool is created.

    uint256 public immutable initialTimestamp;
    address public maxxFinanceTreasury;

    /// @notice block limited or not
    bool public blockLimited;

    /// @notice The number of blocks required 
    uint256 public blocksBetweenTransfers;

    // blacklisted addresses can receive tokens, but cannot send tokens
    modifier notBlocked(address sender) {
        require(
            !isBlocked[sender],
            "ERC20: Account is blocked from transferring"
        );
        _;
    }

    constructor(address _maxxFinanceTreasury, uint256 _transferTax, uint256 _whaleLimit, uint256 _globalSellLimit) ERC20("Maxx Finance", "MAXX") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        maxxFinanceTreasury = _maxxFinanceTreasury;
        _mint(maxxFinanceTreasury, 500000000000 * 10 ** decimals());
        setTransferTax(_transferTax);
        setWhaleLimit(_whaleLimit);
        setGlobalDailySellLimit(_globalSellLimit);
        initialTimestamp = block.timestamp;
    }

    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) external whenNotPaused {
        // Check that the calling account has the minter role
        console.log("enter mint function");
        console.log("msg.sender");
        console.log(msg.sender);
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }

    /// @notice Overrides the burn() function and incrememnts the burnedAmount
    /// @param _amount The amount to burn
    function burn(uint256 _amount) public override {
        burnedAmount += _amount;
        return super.burn(_amount);
    }

    /// @notice Overrides the burnFrom() function and increments the burnedAmount
    /// @param _from The address to burn from
    /// @param _amount The amount to burn
    function burnFrom(address _from, uint256 _amount) public override {
        burnedAmount += _amount;
        return super.burnFrom(_from, _amount);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount) public override notBlocked(msg.sender) whenNotPaused returns (bool) {
        require(_amount < whaleLimit, "ERC20: Transfer amount exceeds whale limit");

        uint32 day = uint32(block.timestamp - initialTimestamp / 24 / 60 / 60);
        require(dailyAmountSold[day] + _amount <= globalDailySellLimit, "ERC20: Daily sell limit exceeded");
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isAllowed[msg.sender] && lastPurchase[msg.sender] >= block.number - blocksBetweenTransfers) {
            isBlocked[msg.sender] = true;
            return false;
        }
        if (isPool[msg.sender]) { // Also occurs if user is withdrawing their liquidity tokens.
            lastPurchase[_to] = block.number;
        } else if (isPool[_to]) {
            dailyAmountSold[day] += _amount;
        }
        if (isPool[_to] || isPool[msg.sender]) {
            uint256 tax = _amount * (TRANSFER_TAX_FACTOR - transferTax) / TRANSFER_TAX_FACTOR;
            _amount -= tax;
            require(super.transfer(maxxFinanceTreasury, tax));
            // require(super.transfer(maxxFinanceTreasury, tax / 2));
            // require(super.burn(tax / 2));
        }
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax on lp pools
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public override notBlocked(_from) whenNotPaused returns (bool) {
        require(_amount < whaleLimit, "ERC20: Transfer amount exceeds whale limit"); 

        uint32 day = uint32(block.timestamp - initialTimestamp / 24 / 60 / 60);
        require(dailyAmountSold[day] + _amount <= globalDailySellLimit, "ERC20: Daily sell limit exceeded");
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (blockLimited && isPool[_to] && !isAllowed[_from] && lastPurchase[_from] >= block.number - blocksBetweenTransfers) {
            isBlocked[_from] = true;
            return false;
        }
        if (isPool[_from]) {
            lastPurchase[_to] = block.number;
        } else if (isPool[_to]) {
            dailyAmountSold[day] += _amount;
        }
        if (isPool[_from] || isPool[_to]) {
             uint256 tax = _amount * (TRANSFER_TAX_FACTOR - transferTax) / TRANSFER_TAX_FACTOR;
            _amount -= tax;
            require(super.transferFrom(msg.sender, maxxFinanceTreasury, tax));
            // require(super.transferFrom(msg.sender, maxxFinanceTreasury, tax / 2));
            // require(super.burnFrom(msg.sender, tax / 2));
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
    function addPool(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPool[_address] = true;
        isAllowed[_address] = true;
    }

    /// @param _transferTax The transfer tax to set
    function setTransferTax(uint256 _transferTax) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_transferTax <= 2000, "ERC20: Transfer tax must be less than or equal to 20%");
        transferTax = _transferTax;
    }

    /// @param _globalDailySellLimit The new global daily sell limit
    function setGlobalDailySellLimit(uint256 _globalDailySellLimit) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_globalDailySellLimit >= GLOBAL_DAILY_SELL_LIMIT_MINIMUM , "Global daily sell limit must be greater than or equal to 1,000,000,000 tokens");
        globalDailySellLimit = _globalDailySellLimit * 10 ** decimals();
    }

    /// @param _whaleLimit The new whale limit
    function setWhaleLimit(uint256 _whaleLimit) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_whaleLimit >= WHALE_LIMIT_MINIMUM, "Whale limit must be greater than or equal to 1,000,000"); 
        whaleLimit = _whaleLimit * 10 ** decimals();
    }

    /// @notice add or remove an address from the allowlist
    /// @param _address The address to add or remove
    /// @param _isAllowed Whether to add (true) or remove (false) the address
    function updateAllowlist(address _address, bool _isAllowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isAllowed[_address] = _isAllowed;
    }

    /// @notice add or remove an address from the blocklist
    /// @param _address The address to add or remove
    /// @param _isBlocked Whether to add (true) or remove (false) the address
    function updateBlocklist(address _address, bool _isBlocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlocked[_address] = _isBlocked;
    }

    /// @notice Update the blocks required between transfers
    /// @param _blocksBetweenTransfers The number of blocks required between transfers
    function updateBlocksBetweenTransfers(uint256 _blocksBetweenTransfers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_blocksBetweenTransfers <= 5, "Blocks between transfers must be less than or equal to 5");
        blocksBetweenTransfers = _blocksBetweenTransfers;
    }

    /// @notice Update blockLimited
    /// @param _blockLimited Whether to block limit or not
    function updateBlockLimited(bool _blockLimited) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blockLimited = _blockLimited;
    }
}