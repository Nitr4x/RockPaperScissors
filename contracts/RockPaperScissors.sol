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
    
    uint public _deadline;
    uint public _timelimit;
    uint public _bet;
    
    mapping(address => Player) public _players;
    
    event LogMovePlaced(address indexed player, bytes32 move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameResolved(address indexed winner, address looser);
    event LogGameCancelled(address indexed player);
    event LogBetWithdrawed(address indexed player, uint amount);
    event LogPlayerPenalized(address indexed player);
    event LogMoveRevealed(address indexed player);
    
    modifier _isActive {
        require(_timelimit > now, "Game ended");
        _;
    }

    modifier _isEnded {
        require(_timelimit < now, "Game is active");
        _;
    }
    
    modifier _isNotResolved {
        require(_timelimit != 0, "Game has been resolved. Use the withdraw function");
        _;
    }

    modifier _isResolved {
        require(_timelimit == 0, "Game has been resolved");
        _;
    }

    constructor(address player1, address player2, uint deadline, uint bet) public {
        require(player1 != address(0x0) && player2 != address(0x0), "Player incorrect");
        require(deadline > 5 minutes, "Deadline too short");

        _deadline = deadline;
        _timelimit = now.add(deadline);
        _bet = bet; 
        
        _players[player1].isPlaying = true;
        _players[player2].isPlaying = true;
    }
    
    function hashMove(address player, bytes32 nonce, Moves move) public view returns(bytes32 hash) {
        require(player != address(0x0), "Invalid address");
        require(nonce != 0 && move != Moves.NONE, "Incorrect nonce or move");
        
        hash = keccak256(abi.encodePacked(address(this), player, move, nonce));
    }
    
    function revealMove(address opponent, bytes32 nonce, Moves move) public _isActive whenNotPaused returns(bool success) {
        require(_players[opponent].hashedMove != 0, "The opponent has not played yet");

        bytes32 hash = hashMove(msg.sender, nonce, move);
        
        require(_players[msg.sender].hashedMove == hash, "Wrong nonce and/or move");
        
        emit LogMoveRevealed(msg.sender);
        
        _players[msg.sender].move = move;
        _timelimit = now.add(_deadline);

        return true;
    }
    
    function resolve(address player1, address player2) public returns(bool success) {
        Moves MPlayer1 = _players[player1].move;
        Moves MPlayer2 = _players[player2].move;

        require(MPlayer1 != Moves.NONE && MPlayer2 != Moves.NONE, "A player has not revealed his move");

        address winner = (MPlayer1 == Moves.ROCK && MPlayer2 == Moves.PAPER) ? player2
            : (MPlayer1 == Moves.PAPER && MPlayer2 == Moves.SCISSORS) ? player2
            : (MPlayer1 == Moves.SCISSORS && MPlayer2 == Moves.ROCK) ? player2
            : player1;
        address looser = (winner == player1) ? player2 : player1;
        
        emit LogGameResolved(winner, looser);

        _players[winner].bet = _players[winner].bet.add(_players[looser].bet);
        _players[looser].bet = 0;
        _timelimit = 0;

        return true;
    }

    function placeMove(bytes32 hash) public _isActive whenNotPaused payable returns(bool success) {
        require(hash != 0 && _players[msg.sender].isPlaying, "Either you don't participate to this game or your move is incorrect");
        require(_players[msg.sender].hashedMove == 0, "You already played");
        require(msg.value == _bet, "Wrong bet");
        
        emit LogMovePlaced(msg.sender, hash);
        
        _players[msg.sender].hashedMove = hash;
        _players[msg.sender].bet = _players[msg.sender].bet.add(msg.value);
        _timelimit = now.add(_deadline);

        return true;
    }
    
    function withdraw() public _isEnded _isResolved returns(bool success) {        
        uint amount = _players[msg.sender].bet;
        
        require(amount > 0, "Nothing to withdraw");
        
        _players[msg.sender].bet = 0;
        
        emit LogBetWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }

    function cancel(address opponent) public _isEnded _isNotResolved returns(bool success) {
        require(_players[msg.sender].isPlaying && _players[opponent].isPlaying, "Yourself or the opponent does not participate to this game");
        require((_players[msg.sender].hashedMove != 0 && _players[opponent].hashedMove == 0)
            || (_players[msg.sender].hashedMove == 0 && _players[opponent].hashedMove == 0), "You cannot cancel the game");

        emit LogGameCancelled(msg.sender);

        _timelimit = 0;

        return true;
    }

    function penalize(address opponent) public _isEnded _isNotResolved returns(bool success) {
        require(_players[msg.sender].isPlaying && _players[opponent].isPlaying, "Yourself or the opponent does not participate to this game");
        require(_players[msg.sender].move != Moves.NONE && _players[opponent].hashedMove != 0 
            && _players[opponent].move == Moves.NONE, "You cannot claim a penality");

        emit LogPlayerPenalized(opponent);

        _players[msg.sender].bet = _players[msg.sender].bet.add(_players[opponent].bet);
        _players[opponent].bet = 0;
        _timelimit = 0;

        return true;
    }
}