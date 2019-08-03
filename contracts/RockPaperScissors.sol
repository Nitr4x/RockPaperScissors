pragma solidity 0.5.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint;

    enum Moves {NONE, ROCK, PAPER, SCISSORS}

    struct Player {
        bytes32 hashedMove;
        Moves move;
        uint bet;
        bool isPlaying;
    }
    
    struct Game {
        uint deadline;
        uint timelimit;
        uint bet;
        address player1;
        address player2;
    }
    
    mapping(address => Game) public _games;
    mapping(address => Player) public _players;

    event LogMovePlaced(address indexed player, bytes32 move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameResolved(address indexed winner, address loser);
    event LogGameCancelled(address indexed player);
    event LogBetWithdrawed(address indexed player, uint amount);
    event LogPlayerPenalized(address indexed player);
    event LogMoveRevealed(address indexed player);
    event LogGameCreated(address indexed game, address player1, address player2);
    event LogGameDestroyed(address indexed player, address game);

    modifier _onlyParticipant(address session) {
        Game memory game = _games[session];

        require((msg.sender == game.player1) || (msg.sender == game.player2), "You don't participe to this game");
        _;
    }

    modifier _isNotResolved(address session) {
        Game memory game = _games[session];

        require(game.timelimit < now && game.timelimit != 0, "Game is active or already resolved");
        _;
    }

    modifier _isResolved(address session) {
        Game memory game = _games[session];

        require(game.timelimit < now && game.timelimit == 0, "Game is active or already resolved");
        _;
    }

    modifier _isActive(address session) {
        require(_games[session].timelimit > now, "Game is over");
        _;
    }

    modifier _isReadyToDestroy(address session) {
         Game memory game = _games[session];

        require(game.timelimit == 0, "Game is not over");
        require(_players[game.player1].bet == 0 && _players[game.player2].bet == 0, "A player has not withdrawed his bet");
        _;
    }
    
    function hashMove(address player, bytes32 nonce, Moves move) public view returns(bytes32 hash) {
        require(player != address(0x0), "Invalid address");
        require(nonce != 0 && move != Moves.NONE, "Incorrect nonce or move");
        
        hash = keccak256(abi.encodePacked(address(this), player, move, nonce));
    }

    function create(address player1, address player2, uint deadline, uint bet) public whenNotPaused returns(bool success) {
        require(player1 != address(0x0) && player2 != address(0x0), "Player incorrect");
        require(_games[player1].deadline != 0, "The creator already did not finish and/or destroy the previous game");
        require(!_players[player1].isPlaying && !_players[player2].isPlaying, "Player not available");
        require(deadline > 5 minutes, "Deadline too short");

        emit LogGameCreated(player1, player1, player2);

        _games[player1].deadline = deadline;
        _games[player1].timelimit = now.add(deadline);
        _games[player1].bet = bet; 
        _games[player1].player1 = player1;
        _games[player2].player2 = player2;

        return true;
    }

    function placeMove(address session, bytes32 hash) public _onlyParticipant(session) _isActive(session) whenNotPaused payable returns(bool success) {
        Game memory game = _games[session];

        require(msg.value == game.bet, "Wrong bet");
        require(_players[msg.sender].hashedMove == 0, "You already played");
        require(hash != 0, "Your move is incorrect");
        
        emit LogMovePlaced(msg.sender, hash);
        
        _players[msg.sender].hashedMove = hash;
        _players[msg.sender].bet = _players[msg.sender].bet.add(msg.value);
        _games[session].timelimit = now.add(game.deadline);

        return true;
    }
        
    function revealMove(address session, bytes32 nonce, Moves move) public _onlyParticipant(session) _isActive(session) whenNotPaused returns(bool success) {
        require(_players[msg.sender].hashedMove != 0, "The opponent has not played yet");

        bytes32 hash = hashMove(msg.sender, nonce, move);
        
        require(_players[msg.sender].hashedMove == hash, "Wrong nonce and/or move");
        
        emit LogMoveRevealed(msg.sender);
        
        _players[msg.sender].move = move;
        _games[session].timelimit = now.add(_games[session].deadline);

        return true;
    }
    
    function resolve(address session) public _onlyParticipant(session) returns(bool success) {
        Game memory game = _games[session];

        Moves MPlayer1 = _players[game.player1].move;
        Moves MPlayer2 = _players[game.player2].move;

        require(MPlayer1 != Moves.NONE && MPlayer2 != Moves.NONE, "A player has not revealed his move");

        address winner = (MPlayer1 == Moves.ROCK && MPlayer2 == Moves.PAPER) ? game.player2
            : (MPlayer1 == Moves.PAPER && MPlayer2 == Moves.SCISSORS) ? game.player2
            : (MPlayer1 == Moves.SCISSORS && MPlayer2 == Moves.ROCK) ? game.player2
            : game.player1;
        address loser = (winner == game.player1) ? game.player2 : game.player1;
        
        emit LogGameResolved(winner, loser);

        _players[winner].bet = _players[winner].bet.add(_players[loser].bet);
        _players[loser].bet = 0;
        _games[session].timelimit = 0;

        return true;
    }
    
    function cancel(address session) public _onlyParticipant(session) _isNotResolved(session) returns(bool success) {
        Game memory game = _games[session];

        address opponent = (msg.sender == game.player1) ? game.player2 : game.player1;

        require((_players[msg.sender].hashedMove != 0 && _players[opponent].hashedMove == 0)
            || (_players[msg.sender].hashedMove == 0 && _players[opponent].hashedMove == 0), "You cannot cancel the game");

        emit LogGameCancelled(msg.sender);

        _games[session].timelimit = 0;

        return true;
    }

    function penalize(address session) public _onlyParticipant(session) _isNotResolved(session) returns(bool success) {
        Game memory game = _games[session];

        address opponent = (msg.sender == game.player1) ? game.player2 : game.player1;

        require(_players[msg.sender].move != Moves.NONE && _players[opponent].hashedMove != 0 
            && _players[opponent].move == Moves.NONE, "You cannot claim a penality");

        emit LogPlayerPenalized(opponent);

        _players[msg.sender].bet = _players[msg.sender].bet.add(_players[opponent].bet);
        _players[opponent].bet = 0;
        _games[session].timelimit = 0;

        return true;
    }

    function withdraw(address session) public _isResolved(session) returns(bool success) {        
        uint amount = _players[msg.sender].bet;
        
        require(amount > 0, "Nothing to withdraw");
        
        _players[msg.sender].bet = 0;
        
        emit LogBetWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }

    function destroy(address session) public _onlyParticipant(session) _isReadyToDestroy(session) returns(bool success) {
        Game memory game = _games[session];

        emit LogGameDestroyed(msg.sender, session);

        delete(_players[game.player1]);
        delete(_players[game.player2]);
        delete(_games[session]);

        return true;
    }
}