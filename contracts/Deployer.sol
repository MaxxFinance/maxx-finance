// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Deployer {
    /// @notice Emitted when a contract is deployed
    event Deployed(address addr, uint256 salt);

    /// @notice Deploys a contract using the create2 method
    /// @param code The bytecode of the contract to deploy
    /// @param salt The salt to use for the create2 method
    function deploy(bytes memory code, uint256 salt) external {
        address addr;
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, salt);
    }
}
