pragma solidity 0.5.10;

import "./SafeMath.sol";

// Handle deadline

contract RockPaperScissors {
    using SafeMath for uint;
    
    struct Player {
        bytes32 move;
        uint balance;
        bool status;
        bool win;
    }
    
    enum Moves {ROCK, PAPER, SCISSORS}
    
    uint public _deadline;
    uint public _bet;
    uint public _participantNb;
    
    mapping(address => Player) public _players;
    
    event LogMovePlaced(address indexed player, bytes32 move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameCreated(address indexed game, uint deadline, uint bet);
    event LogGameResolved(address indexed winner, address looser);
    event LogBalanceWithdrawed(address indexed player, uint amount);
    
    constructor(uint deadline, uint bet) public {
        require(deadline > 5 minutes, "Deadline too short");

        uint limit = now.add(deadline);
        
        emit LogGameCreated(address(this), limit, bet);
        
        _deadline = limit;
        _bet = bet;
        _participantNb = 0;
    }
    
    function enroll() public payable returns(bool success) {
        require(_participantNb < 2, "The game is full");
        require(msg.value == _bet && !_players[msg.sender].status, "Either your bet is incorrect or you already enrolled");
        
        emit LogPlayerEnrolled(msg.sender);
        
        _players[msg.sender] = Player({move: 0, balance: _bet, win: false, status: true});
        _participantNb++;
        
        return true;
    }
    
    function hashMove(bytes32 nonce, uint move) public view returns(bytes32 hash) {
        require(nonce != 0 && move <= uint(Moves.SCISSORS), "Incorrect move or nonce");
        
        hash = keccak256(abi.encodePacked(address(this), msg.sender, move, nonce));
    }
    
    function placeMove(bytes32 hash) public returns(bool success) {
        require(hash != 0 && _players[msg.sender].status, "Either you don't participate to this game or your move is incorrect");
        require(_players[msg.sender].move == 0, "You already played");
        
        emit LogMovePlaced(msg.sender, hash);
        
        _players[msg.sender].move = hash;
        
        return true;
    }

    function resolve(address player1, address player2) public returns(bool success) {
        require(_players[player1].status && _players[player2].status, "Invalid participants");
        require(_players[player1].move != 0 && _players[player2].move != 0, "A player has not played yet");
        
        // Resolve
        
        winner = player1; // to change
        looser = player2;
        
        emit LogGameResolved(winner, looser);

        _players[winner].balance = _players[winner].balance.add(_players[looser].balance);
        _players[winner].won = true;
        _players[looser].balance = 0;
    }
    
    function withdraw() public returns(bool success) {
        require(_players[msg.sender].status && _players[msg.sender].win, "Either you don't participate to this game or you are not the winner");
        
        uint amount = _players[msg.sender].balance;
        
        require(amount > 0, "Nothing to withdraw");
        
        _players[msg.sender].balance = 0;
        
        emit LogBalanceWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }
    
}