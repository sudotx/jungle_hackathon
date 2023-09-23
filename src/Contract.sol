// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// imports
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers

contract Vault is ERC4626, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    // Functions
    constructor(ERC20 _token, string memory _name, string memory _symbol) ERC4626(_token, _name, _symbol) {}
    
    // receive() external payable {}

    // fallback() external payable{}

    // public
    function totalAssets() public view virtual override returns (uint256) {}

    // internal
    //  private
    // internal & private view & pure functions
    // external & public view & pure functions
}

// TODO

// create an erc 4626 vault here ✅
// use a token depository to select what exact erc20 tokens can be accepted by the vault. or any other standard used in the wild
// learn more about it from saved videos
// build it according to the spec lined out in the similar repos you starred
// add a strategy to earn yield for vault participants
// allow users flexibility with vault share token? maybe

// build out solid unit, integration tests
// ensure test coverage exceeds 80%, as a bare minimum
// run slither and take the hints it gives to make tests better
// write deployment scripts, and include tests for that as well

// follow best practices as stated by patrickC
// make code as optimized as possible, with detailed comments
// take hint for comment structure from other mature codebase(s)
