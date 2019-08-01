pragma solidity 0.5.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint;

    enum Moves {ROCK, PAPER, SCISSORS}

    struct Player {
        bytes32 hashedMove;
        uint bet;
        bool isPlaying;
        bool won;
    }
    
    uint public _deadline;
    uint public _bet;
    
    mapping(address => Player) public _players;
    
    event LogMovePlaced(address indexed player, bytes32 move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameResolved(address indexed winner, address looser);
    event LogBalanceWithdrawed(address indexed player, uint amount);
    event LogMoveRevealed(address indexed player);
    
    modifier _isGameNotEnded {
        require(_deadline > now, "Game ended");
        _;
    }
    
    constructor(address player1, address player2, uint deadline, uint bet) public {
        require(player1 != address(0x0) && player2 != address(0x0), "Player incorrect");
        require(deadline > 5 minutes, "Deadline too short");

        _deadline = now.add(deadline);
        _bet = bet; 
        
        _players[player1].isPlaying = true;
        _players[player2].isPlaying = true;
    }
    
    function hashMove(address player, bytes32 nonce, Moves move) public view returns(bytes32 hash) {
        require(player != address(0x0), "Address invalid");
        require(nonce != 0, "Incorrect nonce");
        
        hash = keccak256(abi.encodePacked(address(this), player, move, nonce));
    }
    
    function revealMove(address player, bytes32 nonce, Moves move) internal returns(Moves sMove) {
        bytes32 hash = hashMove(player, nonce, move);
        
        require(_players[player].hashedMove == hash, "Wrong nonce and/or move");
        
        emit LogMoveRevealed(player);
        
        return move;
    }
    
    function resolve(address player1, bytes32 P1Nonce, Moves P1Move,
                        address player2, bytes32 P2Nonce, Moves P2Move) public _isGameNotEnded whenNotPaused returns(bool success) {
        require(_players[player1].hashedMove != 0 && _players[player2].hashedMove != 0, "A player has not played yet");
        
        Moves MPlayer1 = revealMove(player1, P1Nonce, P1Move);
        Moves MPlayer2 = revealMove(player2, P2Nonce, P2Move);
                
        address winner = (MPlayer1 == Moves.ROCK && MPlayer2 == Moves.PAPER) ? player2
            : (MPlayer1 == Moves.PAPER && MPlayer2 == Moves.SCISSORS) ? player2
            : (MPlayer1 == Moves.SCISSORS && MPlayer2 == Moves.ROCK) ? player2
            : player1;
        address looser = (winner == player1) ? player2 : player1;
        
        emit LogGameResolved(winner, looser);

        _players[winner].bet = _players[winner].bet.add(_players[looser].bet);
        _players[winner].won = true;
        _players[looser].bet = _players[looser].bet.sub(_players[looser].bet);
        
        return true;
    }

    function placeMove(bytes32 hash) public _isGameNotEnded whenNotPaused payable returns(bool success) {
        require(hash != 0 && _players[msg.sender].isPlaying, "Either you don't participate to this game or your move is incorrect");
        require(_players[msg.sender].hashedMove == 0, "You already played");
        require(msg.value == _bet, "Wrong bet");
        
        emit LogMovePlaced(msg.sender, hash);
        
        _players[msg.sender].hashedMove = hash;
        _players[msg.sender].bet = _players[msg.sender].bet.add(msg.value);

        return true;
    }
    
    function withdraw() public returns(bool success) {
        require(_players[msg.sender].isPlaying, "You don't participate to this game");
        require(_players[msg.sender].won || now > _deadline, "Either your are not the winner or the game is not ended");
        
        uint amount = _players[msg.sender].bet;
        
        require(amount > 0, "Nothing to withdraw");
        
        _players[msg.sender].bet = 0;
        
        emit LogBalanceWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }
}