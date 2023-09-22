// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

contract Contract {
    uint256 public immutable param;

    constructor(uint256 param_) {
        param = param_;
    }
}

// TODO

// create an erc 4626 vault here
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

