// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Poker} from "src/Poker.sol";
import "forge-std/console.sol";

contract PokerScript is Script {
    Poker pokerInstance = Poker(0x5ae3218Ad358530cBc53305bb9f8b6635AaEd8c6);
    address clientAddy = vm.addr(123456);

    function setUp() public {}

    function run() public {
        console.logAddress(clientAddy);
        vm.startBroadcast();
        bytes32 msgHash = pokerInstance.getMsgHash(msg.sender, clientAddy);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123456, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        pokerInstance.startTable(1000000, 10, clientAddy, 10000000, signature);
        vm.stopBroadcast();
    }
}
