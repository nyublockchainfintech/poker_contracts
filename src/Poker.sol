// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Poker {
    struct Table {
        uint id;
        uint minBuyIn;
        uint8 playerLimit;
        bool inPlay;
        address initiator;
        address[10] players; // there will never be more than 10 players
    }

    mapping(address => bytes) clientKeySig;

    mapping(uint => Table) tables;

    /*
        handels the registration of a off-chain client side signing key. This will store
        the signature of msg.sender in storage so it can later be used to verify signed actions.
        A player must have a registered key before joining a table.
    */
    function register(bytes calldata _sig) external {}

    /*
        Called by players to start a table. They should provide a minimum buy in and a table limit. 
        This should create a new Table and  keep it in storage
    */
    function startTable(uint _minBuyIn, uint8 _playerLimit) external payable {}

    /*
        called by players to joing a table. They must have a signature registered, and
        they must commit at least the min buy in to join
    */
    function joinTable(uint _id) external payable {}

    /*
        called by players to leave a table and take their profits. Before moving money,
        this function must verify hand history. This function must also remove the signature
        associated with the caller 
    */
    function leaveTable(uint _id, bytes calldata _history) external {}

    /*
        This function should verify all the hand histore provided for a specified table.
        Should be used internally when someone tries to leave a table to verify histore and
        moves before sending money out
    */
    function verifyHistory(
        uint _id,
        bytes calldata _history
    ) internal view returns (bool) {}
}
