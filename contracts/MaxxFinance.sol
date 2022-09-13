// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// Account is blocked from transferring tokens
error AccountBlocked();

/// Transfer exceeds the whale limit
error WhaleLimit();

/// Transfer exceeds the daily sell limit
error DailyLimit();

/// New value is out of bounds for consumer protection
error ConsumerProtection();

/// @title Maxx Finance -- MAXX ERC20 token contract
/// @author Alta Web3 Labs - SonOfMosiah
contract MaxxFinance is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // TODO may need to change to private + getter function for inclusion in interface

    /// @notice The amount of MAXX tokens burned
    uint256 public burnedAmount;

    /// @notice Deployment timestamp for this contract
    uint256 public immutable initialTimestamp;

    /// @notice Maxx Finance Vault address
    address public maxxVault;

    /// @notice block limited or not
    bool public isBlockLimited;

    /// @notice Global daily sell limit
    uint256 public globalDailySellLimit;

    /// @notice Whale limit
    uint256 public whaleLimit;

    /// @notice The number of blocks required
    uint256 public blocksBetweenTransfers;

    /// @notice Tax rate when calling transfer() or transferFrom()
    uint16 public transferTax; // 1000 = 10%

    uint64 public constant GLOBAL_DAILY_SELL_LIMIT_MINIMUM = 1000000000; // 1 billion
    uint64 public constant WHALE_LIMIT_MINIMUM = 1000000; // 1 million
    uint8 public constant BLOCKS_BETWEEN_TRANSFERS_MAXIMUM = 5;
    uint16 public constant TRANSFER_TAX_FACTOR = 10000;
    uint64 public constant INITIAL_SUPPLY = 100000000000;

    /// @notice blacklisted addresses
    mapping(address => bool) public isBlocked;

    /// @notice whitelisted addresses
    mapping(address => bool) public isAllowed;

    /// @notice The block number of the address's last purchase from a pool
    mapping(address => uint256) public lastPurchase;

    /// @notice Whether the address is a Maxx token pool or not
    mapping(address => bool) public isPool;

    /// @notice The amount of tokens sold each day
    mapping(uint32 => uint256) public dailyAmountSold;

    constructor(
        address _maxxVault,
        uint16 _transferTax,
        uint256 _whaleLimit,
        uint256 _globalSellLimit
    ) ERC20("Maxx Finance", "MAXX") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        initialTimestamp = block.timestamp;
        maxxVault = _maxxVault;
        _mint(maxxVault, INITIAL_SUPPLY * 10**decimals()); // Initial supply: 100 billion MAXX
        setTransferTax(_transferTax);
        setWhaleLimit(_whaleLimit);
        setGlobalDailySellLimit(_globalSellLimit);
    }

    /// @notice Mints tokens
    /// @dev Increases the token balance of `_to` by `amount`
    /// @param _to The address to mint to
    /// @param _amount The amount to mint
    function mint(address _to, uint256 _amount)
        external
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        _mint(_to, _amount);
    }

    /// @notice identify an address as a liquidity pool
    /// @param _address The pool address
    function addPool(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPool[_address] = true;
        isAllowed[_address] = true;
    }

    /// @notice Set the transfer tax percentage
    /// @param _transferTax The transfer tax to set
    function setTransferTax(uint16 _transferTax)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_transferTax > 2000) {
            revert ConsumerProtection();
        }
        transferTax = _transferTax;
    }

    /// @notice Set the blocks required between transfers
    /// @param _blocksBetweenTransfers The number of blocks required between transfers
    function setBlocksBetweenTransfers(uint256 _blocksBetweenTransfers)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_blocksBetweenTransfers > BLOCKS_BETWEEN_TRANSFERS_MAXIMUM) {
            revert ConsumerProtection();
        }
        blocksBetweenTransfers = _blocksBetweenTransfers;
    }

    /// @notice Update blockLimited
    /// @param _blockLimited Whether to block limit or not
    function updateBlockLimited(bool _blockLimited)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isBlockLimited = _blockLimited;
    }

    /// @notice add an address to the allowlist
    /// @param _address The address to add to the allowlist
    function allow(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isAllowed[_address] = true;
    }

    /// @notice remove an address from the allowlist
    /// @param _address The address to remove from the allowlist
    function disallow(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isAllowed[_address] = false;
    }

    /// @notice add an address to the blocklist
    /// @dev "block" is a reserved symbol in Solidity, so we use "blockUser" instead
    /// @param _address The address to add to the blocklist
    function blockUser(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlocked[_address] = true;
    }

    /// @notice remove an address from the blocklist
    /// @param _address The address to remove from the blocklist
    function unblock(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlocked[_address] = false;
    }

    /// @notice Pause the contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Get the timestamp of the next day when the daily amount sold will be reset
    /// @return timestamp The timestamp corresponding to the next day when the global daily sell limit will be reset
    function getNextDayTimestamp() external view returns (uint256 timestamp) {
        uint256 day = uint256(getCurrentDay() + 1);
        timestamp = initialTimestamp + (day * 1 days);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax on lp pools
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (
            isBlockLimited &&
            isPool[_to] &&
            !isAllowed[msg.sender] &&
            lastPurchase[msg.sender] >= block.number - blocksBetweenTransfers
        ) {
            isBlocked[msg.sender] = true;
            return false;
        }

        if (isPool[_to] || isPool[msg.sender]) {
            uint256 netAmount = (_amount *
                (TRANSFER_TAX_FACTOR - transferTax)) / TRANSFER_TAX_FACTOR;
            uint256 tax = _amount - netAmount;
            _amount = netAmount;
            require(super.transfer(maxxVault, tax / 2));
            burn(tax / 2);
        }
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax on lp pools
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override whenNotPaused returns (bool) {
        // Wallet is blacklisted if they attempt to buy and then sell in the same block or consecutive blocks
        if (
            isBlockLimited &&
            isPool[_to] &&
            !isAllowed[_from] &&
            lastPurchase[_from] >= block.number - blocksBetweenTransfers
        ) {
            isBlocked[_from] = true;
            return false;
        }

        if (isPool[_from] || isPool[_to]) {
            uint256 netAmount = (_amount *
                (TRANSFER_TAX_FACTOR - transferTax)) / TRANSFER_TAX_FACTOR;
            uint256 tax = _amount - netAmount;
            _amount = netAmount;
            require(super.transferFrom(msg.sender, maxxVault, tax / 2));
            burn(tax / 2);
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /// @notice Set the global daily sell limit
    /// @param _globalDailySellLimit The new global daily sell limit
    function setGlobalDailySellLimit(uint256 _globalDailySellLimit)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_globalDailySellLimit < GLOBAL_DAILY_SELL_LIMIT_MINIMUM) {
            revert ConsumerProtection();
        }
        globalDailySellLimit = _globalDailySellLimit * 10**decimals();
    }

    /// @notice Set the whale limit
    /// @param _whaleLimit The new whale limit
    function setWhaleLimit(uint256 _whaleLimit)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_whaleLimit < WHALE_LIMIT_MINIMUM) {
            revert ConsumerProtection();
        }
        whaleLimit = _whaleLimit * 10**decimals();
    }

    /// @notice This functions gets the current day since the initial timestamp
    /// @return day The current day since launch
    function getCurrentDay() public view returns (uint32 day) {
        day = uint32((block.timestamp - initialTimestamp) / 24 / 60 / 60);
        return day;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override(ERC20) {
        bool allowed = isAllowed[_from];
        if ((isBlocked[_to] || isBlocked[_from]) && !allowed) {
            // can't send or receive tokens if the address is blocked
            revert AccountBlocked();
        }

        if (_to == address(0)) {
            // burn | burnFrom
            burnedAmount += _amount; // Burned amount is added to the total burned amount
        }

        if (_from != address(0) && _to != address(0)) {
            // transfer | transferFrom
            if (_amount > whaleLimit && !allowed) {
                revert WhaleLimit();
            }

            if (isPool[_from]) {
                // Also occurs if user is withdrawing their liquidity tokens.
                lastPurchase[_to] = block.number;
            } else if (isPool[_to]) {
                uint32 day = getCurrentDay();
                dailyAmountSold[day] += _amount;
                if (dailyAmountSold[day] > globalDailySellLimit && !allowed) {
                    revert DailyLimit();
                }
            }
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}
