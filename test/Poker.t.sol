// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Poker} from "../src/Poker.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CounterTest is Test {
    Poker public poker;
    ERC20 public token;

    function setUp() public {
        // token = new ERC20("test", "t");
        poker = new Poker(address(token));
    }
}
