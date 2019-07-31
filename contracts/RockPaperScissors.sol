pragma solidity 0.5.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint;

    enum Moves {NONE, ROCK, PAPER, SCISSORS}

    struct Player {
        Moves move;
        bytes32 secret;
        uint balance;
        bool status;
        bool won;
    }
    
    uint public _deadline;
    uint public _bet;
    
    mapping(address => Player) private _players;
    
    event LogMovePlaced(address indexed player, bytes32 move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameResolved(address indexed winner, address looser);
    event LogBalanceWithdrawed(address indexed player, uint amount);
    event LogBetPlaced(address indexed player, uint bet);
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
        
        _players[player1] = Player({secret: 0, move: Moves.NONE, won: false, balance: 0, status: true});
        _players[player2] = Player({secret: 0, move: Moves.NONE, won: false, balance: 0, status: true});
    }
    
    function hashMove(address player, bytes32 nonce, Moves move) public view returns(bytes32 hash) {
        require(player != address(0x0), "Address invalid");
        require(nonce != 0 && move <= Moves.SCISSORS && move > Moves.NONE, "Incorrect move or nonce");
        
        hash = keccak256(abi.encodePacked(address(this), msg.sender, move, nonce));
    }
    
    function placeBet() public _isGameNotEnded whenNotPaused payable returns(bool success) {
        require(_players[msg.sender].status, "Player does not exist");
        require(msg.value == _bet, "Wrong bet");
        
        emit LogBetPlaced(msg.sender, msg.value);
        
        _players[msg.sender].balance = _players[msg.sender].balance.add(msg.value);
        
        return true;
    }
    
    function revealMove(bytes32 nonce, Moves move) public _isGameNotEnded  whenNotPaused returns(bool success) {
        bytes32 hash = hashMove(msg.sender, nonce, move);
        
        require(_players[msg.sender].secret == hash, "Wrong nonce and/or move");
        
        emit LogMoveRevealed(msg.sender);
        
        _players[msg.sender].move = move;
        
        return true;
    }
    
    function resolve(address player1, address player2) public returns(bool success) {
        require(_players[player1].status && _players[player2].status, "Wrong player");
        
        Moves MPlayer1 = _players[player1].move;
        Moves MPlayer2 = _players[player2].move;
        
        require(MPlayer1 != Moves.NONE && MPlayer2 != Moves.NONE, "A player has not reveal his move");
        
        address winner = (MPlayer1 == Moves.ROCK && MPlayer2 == Moves.PAPER) ? player2
            : (MPlayer1 == Moves.PAPER && MPlayer2 == Moves.SCISSORS) ? player2
            : (MPlayer1 == Moves.SCISSORS && MPlayer2 == Moves.ROCK) ? player2
            : player1;
        address looser = (winner == player1) ? player2 : player1;
        
        emit LogGameResolved(winner, looser);

        _players[winner].balance = _players[winner].balance.add(_players[looser].balance);
        _players[winner].won = true;
        _players[looser].balance = _players[looser].balance.sub(_players[looser].balance);
        
        return true;
    }
    
    function placeMove(bytes32 hash) public _isGameNotEnded whenNotPaused returns(bool success) {
        require(hash != 0 && _players[msg.sender].status, "Either you don't participate to this game or your move is incorrect");
        require(_players[msg.sender].secret == 0, "You already played");
        
        emit LogMovePlaced(msg.sender, hash);
        
        _players[msg.sender].secret = hash;
        
        return true;
    }
    
    function withdraw() public returns(bool success) {
        require(_players[msg.sender].status, "You don't participate to this game");
        require(_players[msg.sender].won || now > _deadline, "Either your are not the winner or the game is not ended");
        
        uint amount = _players[msg.sender].balance;
        
        require(amount > 0, "Nothing to withdraw");
        
        _players[msg.sender].balance = 0;
        
        emit LogBalanceWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }
}