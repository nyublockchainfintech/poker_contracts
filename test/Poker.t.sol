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
    uint[] balances2;
    uint[] balancesLeave;
    address[10] playersLeave;
    bytes[] stateStorage;

    function setUp() public {
        token = new ERC20Mock();
        poker = new Poker(address(token));
        for (uint i = 0; i < 11; i++) {
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
    function testStartTableAndJoinFullLimitFail() public {
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

            vm.stopPrank();
        }

        bytes32 messageHash = poker.getMsgHash(players[10], clientAddys[10]);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(
            clientPrivKey[players[10]],
            messageHash
        );
        // Recreate the signature
        bytes memory sig3 = abi.encodePacked(r3, s3, v3);

        vm.startPrank(players[10]);
        token.approve(address(poker), buyIn);
        vm.expectRevert();
        poker.joinTable(1, clientAddys[10], sig3, buyIn);

        vm.stopPrank();
    }

    // test leaving a table
    function testTableStateAfterLeaveNotFull() public {
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

        for (uint i = 1; i < 3; i++) {
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

            vm.stopPrank();
        }

        address[10] memory players2 = [
            players[0],
            players[1],
            players[2],
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];

        balances2.push(5);
        balances2.push(15);
        balances2.push(10);

        bytes32 msgHash2 = poker.getStateMsgHash(players2, balances2);
        bytes[] memory state = new bytes[](3);
        for (uint i = 0; i < 3; i++) {
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(
                clientPrivKey[players[i]],
                msgHash2
            );
            // Recreate the signature
            bytes memory sig3 = abi.encodePacked(r3, s3, v3);
            state[i] = sig3;
        }

        vm.startPrank(players[1]);
        poker.leaveTable(1, state, balances2);
        vm.stopPrank();

        Poker.Table memory table = poker.getTable(1);
        assertEq(table.playerCount, 2);
        assertEq(table.amountInPlay, 15);
        assertEq(table.inPlay, true);
        assertEq(table.initiator, players[0]);
        assertEq(token.balanceOf(address(poker)), 15);
    }

    function testFundHandelingWhenLeavingNotEnding() public {
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

        for (uint i = 1; i < 5; i++) {
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

            vm.stopPrank();
        }
        uint[] memory balancesCopy = new uint[](5);
        balancesCopy[0] = 4;
        balancesCopy[1] = 12;
        balancesCopy[2] = 29;
        balancesCopy[3] = 2;
        balancesCopy[4] = 3;

        balancesLeave.push(4);
        balancesLeave.push(12);
        balancesLeave.push(29);
        balancesLeave.push(2);
        balancesLeave.push(3);

        playersLeave[0] = players[0];
        playersLeave[1] = players[1];
        playersLeave[2] = players[2];
        playersLeave[3] = players[3];
        playersLeave[4] = players[4];

        for (uint i = 4; i > 1; i--) {
            bytes[] memory currState = getSigState(
                playersLeave,
                balancesLeave,
                i + 1
            );

            vm.startPrank(players[i]);
            poker.leaveTable(1, currState, balancesLeave);
            vm.stopPrank();
            playersLeave[i] = address(0);
            balancesLeave.pop();
        }

        Poker.Table memory table = poker.getTable(1);
        assertEq(table.playerCount, 2);
        assertEq(table.amountInPlay, 50 - 3 - 2 - 29);
        assertEq(table.inPlay, true);
        assertEq(table.initiator, players[0]);
        assertEq(token.balanceOf(address(poker)), 50 - 3 - 2 - 29);

        for (uint i = 4; i > 1; i--) {
            assertEq(token.balanceOf(players[i]), 90 + balancesCopy[i]);
        }
    }

    // test payouts

    function testGameEnd() public {
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

        for (uint i = 1; i < 5; i++) {
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

            vm.stopPrank();
        }
        uint[] memory balancesCopy = new uint[](5);
        balancesCopy[0] = 4;
        balancesCopy[1] = 12;
        balancesCopy[2] = 29;
        balancesCopy[3] = 2;
        balancesCopy[4] = 3;

        balancesLeave.push(4);
        balancesLeave.push(12);
        balancesLeave.push(29);
        balancesLeave.push(2);
        balancesLeave.push(3);

        playersLeave[0] = players[0];
        playersLeave[1] = players[1];
        playersLeave[2] = players[2];
        playersLeave[3] = players[3];
        playersLeave[4] = players[4];

        for (uint i = 4; i > 0; i--) {
            bytes[] memory currState = getSigState(
                playersLeave,
                balancesLeave,
                i + 1
            );

            vm.startPrank(players[i]);
            poker.leaveTable(1, currState, balancesLeave);
            vm.stopPrank();
            playersLeave[i] = address(0);
            balancesLeave.pop();
        }
        bytes[] memory currState2 = getSigState(playersLeave, balancesLeave, 1);
        vm.startPrank(players[0]);
        poker.leaveTable(1, currState2, balancesLeave);
        vm.stopPrank();

        Poker.Table memory table = poker.getTable(1);
        assertEq(table.playerCount, 0);
        assertEq(table.amountInPlay, 0);
        assertEq(table.inPlay, false);
        assertEq(table.initiator, address(0));
        assertEq(token.balanceOf(address(poker)), 0);
        assertEq(token.balanceOf(players[0]), 90 + balancesCopy[0]);
    }

    function getSigState(
        address[10] memory currPlayers,
        uint[] memory currBalances,
        uint playerCount
    ) public view returns (bytes[] memory) {
        bytes32 msgHash2 = poker.getStateMsgHash(currPlayers, currBalances);
        bytes[] memory state = new bytes[](playerCount);
        for (uint i = 0; i < playerCount; i++) {
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(
                clientPrivKey[players[i]],
                msgHash2
            );
            // Recreate the signature
            bytes memory sig3 = abi.encodePacked(r3, s3, v3);
            state[i] = sig3;
        }
        return state;
    }
}
