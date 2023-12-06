// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Poker} from "../src/Poker.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import "forge-std/console.sol";

contract CounterTest is Test {
    Poker public poker;
    ERC20Mock public token;
    address[] public players;
    address[] public clientAddys;
    mapping(address => uint) privKey;
    mapping(address => uint) clientPrivKey;

    function setUp() public {
        token = new ERC20Mock();
        poker = new Poker(address(token));
        for (uint i = 0; i < 10; i++) {
            players.push(vm.addr(i + 1));
            clientAddys.push(vm.addr(i + 12));
            privKey[players[i]] = i + 1;
            clientPrivKey[players[i]] = i + 12;
            token.mint(players[i], 100);
            vm.startPrank(players[i]);
            token.approve(address(poker), 100);
            vm.stopPrank();
        }
    }

    function testSimpleStartTableNotFullLimit() public {
        uint minBuyIn = 10;
        uint8 playerLimit = 5;

        uint buyIn = 10;
        bytes32 msgHash = poker.getMsgHash(players[0], clientAddys[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            clientPrivKey[players[0]],
            msgHash
        );
        // Recreate the signature
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(players[0]);
        token.approve(address(poker), buyIn);
        poker.startTable(
            minBuyIn,
            playerLimit,
            clientAddys[0],
            buyIn,
            signature
        );
        vm.stopPrank();

        Poker.Table memory table = poker.getTable(1);
        // check that the table was created correctly
        assertEq(table.playerLimit, playerLimit);
        assertEq(table.minBuyIn, minBuyIn);
        assertEq(table.players[0], players[0]);

        // check that the rest of the players are empty
        assertEq(table.players[1], address(0));
        assertEq(table.players[2], address(0));
        assertEq(table.players[3], address(0));
        assertEq(table.players[4], address(0));
        assertEq(table.players[5], address(0));
        assertEq(table.players[6], address(0));
        assertEq(table.players[7], address(0));
        assertEq(table.players[8], address(0));
        assertEq(table.players[9], address(0));
        // check rest of table state
        assertEq(table.playerCount, 1);
        assertEq(table.amountInPlay, buyIn);
        assertEq(token.balanceOf(address(poker)), buyIn);
        assertEq(table.inPlay, true);
        assertEq(table.initiator, players[0]);
    }

    function testStartTableAndJoinNotFullLimit() public {
        uint minBuyIn = 10;
        uint8 playerLimit = 5;

        uint buyIn = 10;
        bytes32 msgHash = poker.getMsgHash(players[0], clientAddys[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            clientPrivKey[players[0]],
            msgHash
        );
        // Recreate the signature
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(players[0]);
        token.approve(address(poker), buyIn);
        poker.startTable(
            minBuyIn,
            playerLimit,
            clientAddys[0],
            buyIn,
            signature
        );
        vm.stopPrank();

        vm.startPrank(players[1]);
        token.approve(address(poker), buyIn);
        bytes32 msgHash2 = poker.getMsgHash(players[1], clientAddys[1]);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            clientPrivKey[players[1]],
            msgHash2
        );
        // Recreate the signature
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);
        poker.joinTable(1, clientAddys[1], sig2, buyIn);
        vm.stopPrank();

        Poker.Table memory table = poker.getTable(1);
        // check that the table was created correctly
        assertEq(table.playerCount, 2);
        assertEq(table.amountInPlay, buyIn * 2);
        assertEq(token.balanceOf(address(poker)), buyIn * 2);
        assertEq(table.inPlay, true);
        assertEq(table.initiator, players[0]);
        assertEq(table.players[0], players[0]);
        assertEq(table.players[1], players[1]);
    }

    function testStartTableAndJoinFullLimit() public {
        uint minBuyIn = 10;
        uint8 playerLimit = 10;

        uint buyIn = 10;

        bytes32 msgHash = poker.getMsgHash(players[0], clientAddys[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            clientPrivKey[players[0]],
            msgHash
        );
        // Recreate the signature
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(players[0]);
        token.approve(address(poker), buyIn);
        poker.startTable(
            minBuyIn,
            playerLimit,
            clientAddys[0],
            buyIn,
            signature
        );
        vm.stopPrank();

        for (uint i = 1; i < 10; i++) {
            bytes32 messageHash = poker.getMsgHash(players[i], clientAddys[i]);
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
                clientPrivKey[players[i]],
                messageHash
            );
            // Recreate the signature
            bytes memory sig = abi.encodePacked(r2, s2, v2);

            vm.startPrank(players[i]);
            token.approve(address(poker), buyIn);
            poker.joinTable(1, clientAddys[i], sig, buyIn);
            console.logString("player joined");
            vm.stopPrank();
        }

        Poker.Table memory table = poker.getTable(1);
        // check that the table was created correctly
        assertEq(table.playerCount, 10);
        assertEq(table.amountInPlay, buyIn * 10);
        assertEq(table.inPlay, true);
        assertEq(table.initiator, players[0]);
        assertEq(token.balanceOf(address(poker)), buyIn * 10);

        for (uint i = 0; i < 10; i++) {
            assertEq(table.players[i], players[i]);
        }
    }

    // test that a player can't join a table that is full

    // test leaving a table

    // test payouts
}
