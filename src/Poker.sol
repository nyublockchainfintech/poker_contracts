// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Poker {
    uint8 constant MAX_PLAYERS = 10;

    struct Table {
        uint id;
        uint minBuyIn;
        uint8 playerLimit;
        bool inPlay;
        address initiator;
        address[MAX_PLAYERS] players; // there will never be more than 10 players
    }

    struct ClientKeySig {
        uint gameId;
        bytes32 sig;
    }

    mapping(address => ClientKeySig[]) clientKeySig;
    mapping(uint => Table) tables;

    uint private _id;

    event TableCreated(uint id, address indexed creator);

    /*
        Called by players to start a table. They should provide a minimum buy in and a table limit. 
        This should create a new Table and  keep it in storage
    */
    function startTable(uint _minBuyIn, uint8 _playerLimit) external payable {
        // check that the creator has a registered key
        if (clientKeySig[msg.sender].length == 0) revert();

        tables[_id] = Table(
            ++_id,
            _minBuyIn,
            _playerLimit,
            false,
            msg.sender,
            [
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0)
            ]
        );

        emit TableCreated(_id, msg.sender);
    }

    /*
        this function is responsible both for registering a addy for the client to sign actions 
        with for this specific game, verifying this signature, and setting this player
        in the game in storage
    */
    function join(uint _gameId, address _clientAddy, bytes memory _sig) public {
        // the game must exist already
        if (_gameId > _id) revert();

        // check that the sig isn't already registered in the match
        if (!isInGame(msg.sender, _gameId)) revert();

        verifySig(msg.sender, _clientAddy, _sig);
    }

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

    function isInGame(address _addy, uint _gameId) public view returns (bool) {
        Table memory table = tables[_gameId];
        for (uint8 i = 0; i < table.playerLimit; ) {
            if (table.players[i] == _addy) {
                return true;
            } else if (table.players[i] == address(0)) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    // verifies that _addy did indeed sign a message that registers a client priv key
    function verifySig(
        address _signer,
        address _clientAddy,
        bytes memory _sig
    ) internal view returns (bool) {
        bytes32 msgHash = getMsgHash(_signer, _clientAddy);
    }

    function getMsgHash(
        address _player,
        address _playerClientAddy
    ) public pure returns (bytes32) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_player, _playerClientAddy)
        );
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
            );
    }
}
