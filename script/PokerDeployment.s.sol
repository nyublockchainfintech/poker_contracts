// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Poker} from "src/Poker.sol";
import {ERC20Mock} from "mocks/ERC20Mock.sol";
import "forge-std/console.sol";

contract PokerDeployment is Script {
    Poker pokerInstance;
    address clientAddy = vm.addr(123456);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        ERC20Mock usdc = new ERC20Mock();
        pokerInstance = new Poker(address(usdc));
        usdc.approve(address(pokerInstance), 10000000);
        bytes32 msgHash = pokerInstance.getMsgHash(
            0x3D4bDd0Daa396FA0b8B488FA7faF9050cb944239,
            clientAddy
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123456, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        pokerInstance.startTable(1000000, 10, clientAddy, 10000000, signature);
        vm.stopBroadcast();
    }
}
