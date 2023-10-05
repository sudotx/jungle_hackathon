// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {Vault} from "./Vault.sol";

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title Vault Factory
/// @author tx
/// @notice Factory used to deploy isolated Vaults for any ERC20 token.
contract VaultFactory is Auth {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a Vault factory.
    /// @param _owner The owner of the factory.
    /// @param _authority The Authority of the factory.
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    /*///////////////////////////////////////////////////////////////
                        VAULT DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice A counter indicating how many Vaults have been deployed.
    /// @dev This is used to generate the vault ID.
    uint256 public vaultNumber;

    /// @dev When a new vault is deployed, it will retrieve the
    /// value stored here.
    string public vaultDeploymentName;

    /// @notice Emitted when a new Vault is deployed.
    /// @param vault The newly deployed vault.
    /// @param deployer The address of the vault deployer.
    event VaultDeployed(uint256 indexed id, Vault indexed vault, address indexed deployer);

    /// @notice Deploy a new Vault.
    /// @return vault The address of the newly deployed vault.
    function deployVault(ERC20 underlying) external returns (Vault vault, uint256 index) {
        // Calculate pool ID.

        // Unchecked is safe here because index will never reach type(uint256).max
        unchecked {
            index = vaultNumber + 1;
        }

        // Update state variables.
        vaultNumber = index;

        // Deploy the Vault using the CREATE2 opcode.
        vault = new Vault{salt: address(underlying).fillLast12Bytes()}(underlying, "", "");

        // Emit the event.
        emit VaultDeployed(index, vault, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT RETRIEVAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a Vault's address from its accepted underlying token.
    /// @param underlying The ERC20 token that the Vault should accept.
    /// @return The address of a Vault which accepts the provided underlying token.
    /// @dev The Vault returned may not be deployed yet. Use isVaultDeployed to check.
    /// @dev Order is important here:
    /// Prefix
    /// Creator
    /// Salt
    /// Bytecode hash
    /// Deployment bytecode
    /// Constructor arguments
    function getVaultFromUnderlying(ERC20 underlying) external view returns (Vault) {
        return Vault(
            payable(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xFF),
                        address(this),
                        address(underlying).fillLast12Bytes(),
                        keccak256(abi.encodePacked(type(Vault).creationCode, abi.encode(underlying)))
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
            )
        );
    }

    /// @notice Returns if a Vault at an address has already been deployed.
    /// @param vault The address of a Vault which may not have been deployed yet.
    /// @return A boolean indicating whether the Vault has been deployed already.
    /// @dev This function is useful to check the return values of getVaultFromUnderlying,
    /// as it does not check that the Vault addresses it computes have been deployed yet.
    function isVaultDeployed(Vault vault) external view returns (bool) {
        return address(vault).code.length > 0;
    }
}
