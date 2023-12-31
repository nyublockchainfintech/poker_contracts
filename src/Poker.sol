// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";

contract Poker is ReentrancyGuard {
    uint8 constant MAX_PLAYERS = 10;

    struct Table {
        uint id;
        uint minBuyIn;
        uint8 playerLimit;
        uint8 playerCount;
        bool inPlay;
        address initiator;
        uint amountInPlay;
        address[MAX_PLAYERS] players; // there will never be more than 10 players
    }

    // each player can have multiple client private keys if they are multitabling (1 per game)
    mapping(address player => mapping(uint gameId => address))
        private clientAddy;
    mapping(uint gameId => Table) public tables;

    // incrementing id to indetify games
    uint public _currId;

    uint public _numPurgedGames;

    IERC20 private _paymentToken;

    // indexed event to query events easier - will be needed for FE
    event TableCreated(uint indexed id, address indexed creator);
    event JoinedGame(address indexed player, uint indexed id);

    constructor(address paymentToken) {
        _paymentToken = IERC20(paymentToken);
    }

    /*
        Called by players to start a table. They should provide a minimum buy in and a table limit. 
        This should create a new Table and  keep it in storage
    */
    // think about how to structure logic to remove reentrancy modifier to save gas
    function startTable(
        uint _minBuyIn,
        uint8 _playerLimit,
        address _clientAddy,
        uint _buyIn,
        bytes memory _sig
    ) external payable nonReentrant {
        if (_buyIn < _minBuyIn) revert("insufficient buy in");

        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender][++_currId] = _clientAddy;

        _paymentToken.transferFrom(msg.sender, address(this), _buyIn);

        // store table at next available id
        tables[_currId] = Table(
            _currId,
            _minBuyIn,
            _playerLimit,
            1,
            true,
            msg.sender,
            _buyIn,
            [
                msg.sender,
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

        emit TableCreated(_currId, msg.sender);
    }

    /*
        this function is responsible both for registering a addy for the client to sign actions 
        with for this specific game, verifying this signature, and setting this player
        in the game in storage
    */

    // think about how to structure logic to remove reentrancy modifier to save gas
    function joinTable(
        uint _gameId,
        address _clientAddy,
        bytes memory _sig,
        uint _buyIn
    ) public payable nonReentrant {
        // the game must exist already
        if (_gameId > _currId) revert("game does not exist");

        // used downstream for checks
        Table memory table = tables[_gameId];

        if (_buyIn < table.minBuyIn) revert("insufficient buy in");

        // check that the sig isn't already registered in the match
        if (isInGame(msg.sender, table)) revert("already in game");

        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender][_gameId] = _clientAddy;

        //add the caller to the game if not full
        if (isAtCapacity(table)) revert("game is full");
        // transfer tokens into contract
        _paymentToken.transferFrom(msg.sender, address(this), _buyIn);

        // add player to contract stroage
        tables[_gameId].players[table.playerCount] = msg.sender;
        ++tables[_gameId].playerCount;
        tables[_gameId].amountInPlay += _buyIn;

        emit JoinedGame(msg.sender, _gameId);
    }

    /*
        called by players to leave a table and take their profits. Before moving money,
        this function must verify hand history. This function must also remove the signature
        associated with the caller 
    */
    function leaveTable(
        uint _id,
        bytes[] memory _state,
        uint[] memory _balances
    ) external nonReentrant {
        Table memory table = tables[_id];
        if (!isInGame(msg.sender, table)) revert("must be in game");
        if (_state.length != _balances.length)
            revert("signatures and balances must be equal");
        if (_state.length != table.playerCount)
            revert("signatures don't match player count");

        verifyHistory(table, _state, _balances);

        --tables[_id].playerCount;
        uint index = findPlayer(table.players, msg.sender);

        tables[_id].players[index] = address(0);
        if (index != table.playerCount) {
            shiftDown(_id, index);
        }

        // ensures that users cannot collude to steal other table money
        if (_balances[index] > table.amountInPlay)
            ("cannot withdraw more than table balance");
        tables[_id].amountInPlay -= _balances[index];
        _paymentToken.transfer(msg.sender, _balances[index]);

        // remove client addy from storage
        delete clientAddy[msg.sender][_id];

        // if the table is empty, remove it from storage

        if (tables[_id].playerCount == 0) {
            tables[_id].inPlay = false;
            ++_numPurgedGames;
            delete tables[_id];
        }
    }

    function shiftDown(uint _id, uint indexFrom) internal {
        // shift down players array
        Table storage table = tables[_id];
        for (uint i = indexFrom; i < table.playerCount + 1; ) {
            table.players[i] = table.players[i + 1];
            unchecked {
                ++i;
            }
        }
    }

    /*
        called by players to leave a table and take their profits. Before moving money,
        this function must verify hand history. This function must also remove the signature
        associated with the caller 
    */

    function findPlayer(
        address[MAX_PLAYERS] memory _players,
        address _addy
    ) internal view returns (uint) {
        for (uint i = 0; i < _players.length; ) {
            if (_players[i] == _addy) return i;
            unchecked {
                ++i;
            }
        }
        return MAX_PLAYERS + 1;
    }

    /*
        This function should verify all the hand histore provided for a specified table.
        Should be used internally when someone tries to leave a table to verify histore and
        moves before sending money out
    */
    function verifyHistory(
        Table memory _table,
        bytes[] memory _state,
        uint[] memory _balances
    ) internal view {
        for (uint8 i = 0; i < _table.playerCount; ) {
            bytes32 msgHash = getStateMsgHash(_table.players, _balances);
            address recovered = recoverSigner(msgHash, _state[i]);

            if (recovered != clientAddy[_table.players[i]][_table.id])
                revert("invalid signature");

            unchecked {
                ++i;
            }
        }
    }

    function getStateMsgHash(
        address[MAX_PLAYERS] memory _players,
        uint[] memory _balances
    ) public pure returns (bytes32) {
        bytes32 msgHash = keccak256(abi.encodePacked(_players, _balances));
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
            );
    }

    function isAtCapacity(uint _gameId) public view returns (bool) {
        Table memory table = tables[_gameId];
        return (table.playerLimit == table.playerCount);
    }

    // overload for internal gas management reasons
    function isAtCapacity(Table memory table) internal pure returns (bool) {
        return (table.playerLimit == table.playerCount);
    }

    function isInGame(address _addy, uint _gameId) public view returns (bool) {
        Table memory table = tables[_gameId];
        for (uint8 i = 0; i < table.playerCount; ) {
            if (table.players[i] == _addy) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    // overload for internal gas management reasons
    function isInGame(
        address _addy,
        Table memory table
    ) internal view returns (bool) {
        for (uint8 i = 0; i < table.playerCount; ) {
            if (table.players[i] == _addy) {
                return true;
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
    ) internal view {
        bytes32 msgHash = getMsgHash(_signer, _clientAddy);
        address recovered = recoverSigner(msgHash, _sig);
        if (recovered != _clientAddy) revert("invalid signature");
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
            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }
    }

    function getTable(uint _id) public view returns (Table memory) {
        return tables[_id];
    }

    function getPlayers(
        uint _id
    ) public view returns (address[MAX_PLAYERS] memory) {
        return tables[_id].players;
    }

    /*
    SHOULD ONLY BE CALLED OFF CHAIN
    */
    function getAllTables() public view returns (Table[] memory) {
        Table[] memory allTables = new Table[](_currId - _numPurgedGames);
        uint insertIndex = 0;
        for (uint i = 0; i < _currId; ) {
            if (tables[i].inPlay) {
                allTables[insertIndex] = tables[i];
                unchecked {
                    ++insertIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        return allTables;
    }
}
