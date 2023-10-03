// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import {Test} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @notice Build yield generating strategies with <STRATEGY> and ERC-4626
contract VaultTest is Test {
    address weth_whale = 0x6555e1CC97d3cbA6eAddebBCD7Ca51d75771e0B8;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    ERC20 wethToken = MockERC20(WETH);
    MockERC20 underlying;
    Vault vault;
    address constant alice = address(1);

    function setUp() public {
        uint256 number = 43;
        assertEq(number, 43);
        emit log("deploy MockERC20");
        underlying = new MockERC20("Mock Token", "TKN", 18);
        emit log("here");
        vault = new Vault(underlying, "Short $XXX Vault", "PPP-WETH");
        emit log("post deploy");

        // Give Alice some mock tokens, ~$315k worth
        underlying.mint(alice, 2_000e18);
    }

    function testDeposit() public {
        vm.prank(alice);
        vault.deposit(2000e18, alice);
    }
    /// @notice Create a safe, to use the created strategy
    function testCreateSafeWithStrategy() public {}

}
