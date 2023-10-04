// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Vault, VaultFactory} from "src/VaultFactory.sol";


import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {MockERC20} from "../mocks/MockERC20.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Test} from "forge-std/Test.sol";

/// @title Lending Pool Factory Test Contract
contract VaultFactoryTest is DSTestPlus {
    // Used variables.
    // Vault vault;
    
    function setUp() public {
        // Deploy Lending Pool Factory.
        // factory = new Vault(address(this), Authority(address(0)));
        // Vault factory = new Vault(ERC20(token), "Tokens Vault", "TKN VLT");
        // VaultFactory factory = new VaultFactory(address(this), Authority(address(0)));
    }
    
    function testDeployVault() public {
        // Arrange
        VaultFactory factory = new VaultFactory(address(this), Authority(address(0)));
        (Vault vault, uint256 id) = factory.deployVault("Test Vault");
        
        // Assert
        assertEq(factory.vaultNumber(), 1);
        assertEq(factory.vaultDeploymentName(), "Test Vault");
        assertEq(factory.owner(), address(this));
        
        assertEq(address(vault), address(factory.getVaultFromNumber(id)));
        assertGt(address(vault).code.length, 0);
    }
    
    function testVaultNumberIncrement() public {
        // Arrange
        VaultFactory factory = new VaultFactory(address(this), Authority(address(0)));
        (Vault vault1, uint256 id1) = factory.deployVault("Test Vault 1");
        (Vault vault2, uint256 id2) = factory.deployVault("Test Vault 2");

        // Assert
        assertFalse(id1 == id2);
        assertFalse(vault1 == vault2);
        assertEq(factory.vaultNumber(), 2);
    }
}
