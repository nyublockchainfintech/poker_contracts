// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Poker is ReentrancyGuard {
    uint8 constant MAX_PLAYERS = 10;

    struct ClientAddy {
        uint gameId;
        address clientAddy;
    }

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
    mapping(address player => ClientAddy[]) clientAddy;
    mapping(uint gameId => Table) tables;

    // incrementing id to indetify games
    uint private _currId;

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
        if (_buyIn < _minBuyIn) revert();

        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender].push(ClientAddy(++_currId, _clientAddy));

        _paymentToken.transferFrom(msg.sender, address(this), _buyIn);

        // store table at next available id
        tables[_currId] = Table(
            _currId,
            _minBuyIn,
            _playerLimit,
            1,
            false,
            msg.sender,
            _buyIn,
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

        emit TableCreated(_currId, msg.sender);
    }

    /*
        this function is responsible both for registering a addy for the client to sign actions 
        with for this specific game, verifying this signature, and setting this player
        in the game in storage
    */

    // think about how to structure logic to remove reentrancy modifier to save gas
    function join(
        uint _gameId,
        address _clientAddy,
        bytes memory _sig,
        uint _buyIn
    ) public payable nonReentrant {
        // the game must exist already
        if (_gameId > _currId) revert();

        // used downstream for checks
        Table memory table = tables[_gameId];

        if (_buyIn < table.minBuyIn) revert();

        // check that the sig isn't already registered in the match
        if (isInGame(msg.sender, table)) revert();

        // verify that msg.sender does indeed have access to the priv key on client
        verifySig(msg.sender, _clientAddy, _sig);

        //add sig to storage
        clientAddy[msg.sender].push(ClientAddy(_gameId, _clientAddy));

        //add the caller to the game if not full
        if (!isAtCapacity(table)) {
            // transfer tokens into contract
            _paymentToken.transferFrom(msg.sender, address(this), _buyIn);

            // add player to contract stroage
            tables[_gameId].players[table.playerCount] = msg.sender;
            ++tables[_gameId].playerCount;
            tables[_gameId].amountInPlay += _buyIn;

            emit JoinedGame(msg.sender, _gameId);
        }
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
    ) external {
        Table memory table = tables[_id];
        if (!isInGame(msg.sender, table)) revert();
        if (_state.length != _balances.length) revert();
        if (_state.length != table.players.length) revert();

        verifyHistory(table, _state, _balances);

        --tables[_id].playerCount;
        uint index = findPlayer(table.players, msg.sender);

        tables[_id].players[index] = address(0);

        // ensures that users cannot collude to steal other table money
        if (_balances[index] > table.amountInPlay) revert();
        _paymentToken.transfer(msg.sender, _balances[index]);
    }

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
        for (uint8 i = 0; i < _state.length; ) {
            bytes32 msgHash = getStateMsgHash(_table.players, _balances);
            address recovered = recoverSigner(msgHash, _state[i]);
            if (recovered != _table.players[i]) revert();
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
        return (table.playerLimit == getPlayerCount(table));
    }

    // overload for internal gas management reasons
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

    // overload for internal gas management reasons
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
    ) internal pure returns (bool) {
        for (uint8 i = 0; i < table.playerLimit; ) {
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
            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }
    }
}
