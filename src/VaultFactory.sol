// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Vault} from "./Vault.sol";

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title Lending Pool Factory
/// @author tx
/// @notice Factory used to deploy isolated Vaults.
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
                        POOL DEPLOYMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice A counter indicating how many Vaults have been deployed.
    /// @dev This is used to generate the vault ID.
    uint256 public vaultNumber;

    /// @dev When a new pool is deployed, it will retrieve the
    /// value stored here. This enables the lending to be deployed to
    /// an address that does not require the name to determine.
    string public vaultDeploymentName;

    /// @notice Emitted when a new Vault is deployed.
    /// @param vault The newly deployed vault.
    /// @param deployer The address of the vault deployer.
    event VaultDeployed(uint256 indexed id, Vault indexed vault, address indexed deployer);

    /// @notice Deploy a new Vault.
    /// @return vault The address of the newly deployed vault.
    function deployVault(string memory name) external returns (Vault vault, uint256 index) {
        // Calculate pool ID.
        
        // Unchecked is safe here because index will never reach type(uint256).max
        unchecked { index = vaultNumber + 1; }

        // Update state variables.
        vaultNumber = index;
        vaultDeploymentName = name;

        // Deploy the LendingPool using the CREATE2 opcode.
        vault = new Vault{salt: bytes32(index)}(ERC20(msg.sender), "", "");

        // Emit the event.
        emit VaultDeployed(index, vault, msg.sender);

        // Reset the deployment name.
        delete vaultDeploymentName;
    }

    /*///////////////////////////////////////////////////////////////
                        POOL RETRIEVAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the address of a pool given its ID.
    function getVaultFromNumber(uint256 id) external view returns (Vault vault) {
        // Retrieve the lending pool.
        return
            Vault(
                payable(
                    keccak256(
                        abi.encodePacked(
                            // Prefix:
                            bytes1(0xFF),
                            // Creator:
                            address(this),
                            // Salt:
                            bytes32(id),
                            // Bytecode hash:
                            keccak256(
                                abi.encodePacked(
                                    // Deployment bytecode:
                                    type(Vault).creationCode
                                )
                            )
                        )
                    ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
                )
            );
    }
}
