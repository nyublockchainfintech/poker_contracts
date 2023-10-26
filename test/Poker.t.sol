// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Poker} from "../src/Poker.sol";

contract CounterTest is Test {
    Poker public poker;

    function setUp() public {
        poker = new Poker();
    }
}
