// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MAXX is ERC20, ERC20Burnable, Ownable {

    address maxxFinanceTreasury;

    /// @notice Tax rate when calling transfer() or tranferFrom()
    uint256 public TRANSFER_TAX;

    constructor() ERC20("Maxx Finance", "MAXX") {
        _mint(maxxFinanceTreasury, 500000000000 * 10 ** decimals());
    }

    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @dev Overrides the transfer() function and implements a transfer tax
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _amount = ((_amount * TRANSFER_TAX) / 10000);
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides the transferFrom() function and implements a transfer tax
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _amount = ((_amount * TRANSFER_TAX) / 10000);
        return super.transferFrom(_from, _to, _amount);
    }

    /// @notice Should be called by users to avoid the transfer tax
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function freeTransfer(address _to, uint256 _amount) public returns (bool) {
        return super.transfer(_to, _amount);
    }

    /// @notice Should be called by users to avoid the transfer tax
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    /// @return Whether the transfer was successful
    function freeTransferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        return super.transferFrom(_from, _to, _amount);
    }
}