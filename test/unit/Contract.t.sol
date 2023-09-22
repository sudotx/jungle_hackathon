// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";

contract ContractTest is Test {
    function setUp() public {}

    function testExample() public {
        vm.startPrank(address(0xB0B));
        emit log("Hello world!");
        assertTrue(true);
    }
}
