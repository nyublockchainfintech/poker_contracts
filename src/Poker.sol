// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Poker {
    uint8 constant MAX_PLAYERS = 10;

    struct ClientAddy {
        uint gameId;
        address clientAddy;
    }

    // not implemented yet but every player should be modeled by this struct not just an address
    struct Player {
        uint buyIn;
        address addy;
    }

    struct Table {
        uint id;
        uint minBuyIn;
        uint8 playerLimit;
        bool inPlay;
        address initiator;
        address[MAX_PLAYERS] players; // there will never be more than 10 players
    }

    // each player can have multiple client private keys if they are multitabling (1 per game)
    mapping(address player => ClientAddy[]) clientAddy;
    mapping(uint gameId => Table) tables;

    // incrementing id to indetify games
    uint private _id;

    // indexed event to query events easier - will be needed for FE
    event TableCreated(uint indexed id, address indexed creator);

    /*
        Called by players to start a table. They should provide a minimum buy in and a table limit. 
        This should create a new Table and  keep it in storage
    */
    function startTable(
        uint _minBuyIn,
        uint8 _playerLimit,
        address _clientAddy,
        bytes memory _sig
    ) external payable {
        // check that the creator has a registered key
        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender].push(ClientAddy(++_id, _clientAddy));

        //

        // store table at next available id
        tables[_id] = Table(
            _id,
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
        Table memory table = tables[_gameId];

        // check that the sig isn't already registered in the match
        if (!isInGame(msg.sender, table)) revert();

        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender].push(ClientAddy(_gameId, _clientAddy));

        //add the caller to the game if not full
        if (!isAtCapacity(table)) {
            // transfer tokens into contract
            // add player to contract stroage
        }
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

    function isAtCapacity(uint _gameId) public view returns (bool) {
        Table memory table = tables[_gameId];
        return (table.playerLimit == getPlayerCount(table));
    }

    function isAtCapacity(Table memory table) internal pure returns (bool) {
        return (table.playerLimit == getPlayerCount(table));
    }

    function getPlayerCount(uint _gameId) public view returns (uint8) {
        Table memory table = tables[_gameId];
        for (uint8 i = 0; i < table.playerLimit; ) {
            if (table.players[i] == address(0)) {
                return i;
            }
            unchecked {
                ++i;
            }
        }

        return table.playerLimit;
    }

    function getPlayerCount(Table memory table) internal pure returns (uint8) {
        for (uint8 i = 0; i < table.playerLimit; ) {
            if (table.players[i] == address(0)) {
                return i;
            }
            unchecked {
                ++i;
            }
        }

        return 0;
    }

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

    function isInGame(
        address _addy,
        Table memory table
    ) internal pure returns (bool) {
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
    ) internal pure {
        bytes32 msgHash = getMsgHash(_signer, _clientAddy);
        address recovered = recoverSigner(msgHash, _sig);
        if (recovered != _clientAddy) revert();
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

    function recoverSigner(
        bytes32 _msgHash,
        bytes memory _sig
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_sig);
        return ecrecover(_msgHash, v, r, s);
    }

    function splitSignature(
        bytes memory _sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(_sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }
    }
}
