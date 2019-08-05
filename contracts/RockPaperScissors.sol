pragma solidity 0.5.10;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint;

    enum Moves {NONE, ROCK, PAPER, SCISSORS}

    uint constant minDeadline = 5 minutes;

    struct Game {
        uint deadline;
        uint timelimit;
        uint bet;
        address opponent;
        Moves opponentMove;
    }
    
    mapping(bytes32 => Game) public games;
    mapping(address => uint) public balances;

    event LogMovePlaced(bytes32 indexed session, address player, Moves move);
    event LogPlayerEnrolled(address indexed player);
    event LogGameResolved(bytes32 indexed session, address winner, address loser);
    event LogGameCancelled(bytes32 indexed session, address player);
    event LogBetWithdrawed(address indexed player, uint amount);
    event LogPlayerPenalized(bytes32 indexed session, address player);
    event LogGameCreated(bytes32 indexed session, address player1, address player2);
    event LogGameDestroyed(bytes32 indexed session, address player);

    function hashMove(address player, bytes32 nonce, Moves move) public view returns(bytes32 hash) {
        require(player != address(0x0), "Invalid address");
        require(nonce != 0 && move != Moves.NONE, "Incorrect nonce or move");
        
        hash = keccak256(abi.encodePacked(address(this), player, move, nonce));
    }

    function create(bytes32 hashedMove, address opponent, uint deadline, uint bet) public whenNotPaused payable returns(bool success) {
        require(msg.value != bet, "The ether amount sent and the bet are not equal");
        require(opponent != address(0x0) && hashedMove != 0, "Opponent or move incorrect");
        require(games[hashedMove].deadline != 0, "This game already exist");
        require(deadline > minDeadline, "Deadline too short");

        emit LogGameCreated(hashedMove, msg.sender, opponent);

        games[hashedMove].deadline = deadline;
        games[hashedMove].timelimit = now.add(deadline);
        games[hashedMove].bet = bet; 
        games[hashedMove].opponent = opponent;

        return true;
    }

    function placeMove(bytes32 session, Moves move) public whenNotPaused payable returns(bool success) {
        Game memory game = games[session];

        require(game.timelimit > now && game.bet != 0, "Game is over");
        require(game.opponent == msg.sender, "You don't participate to this game");
        require(msg.value == game.bet, "Wrong bet");
        require(move != Moves.NONE, "Wrong move");
        require(game.opponentMove == Moves.NONE, "You already played");
        
        emit LogMovePlaced(session, msg.sender, move);
        
        games[session].opponentMove = move;
        games[session].timelimit = now.add(game.deadline);

        return true;
    }

    function resolve(bytes32 session, bytes32 nonce, Moves move) public whenNotPaused returns(bool success) {        
        require(session == hashMove(msg.sender, nonce, move), "Wrong nonce and/or move. Note: only the game creator can resolve the game");

        Game memory game = games[session];

        require(game.timelimit > now && game.bet != 0, "Game is over");
        require(game.opponentMove != Moves.NONE, "The opponent has not played yet");

        address winner = (move == Moves.ROCK && game.opponentMove == Moves.PAPER) ? game.opponent
            : (move == Moves.PAPER && game.opponentMove == Moves.SCISSORS) ? game.opponent
            : (move == Moves.SCISSORS && game.opponentMove == Moves.ROCK) ? game.opponent
            : msg.sender;
        address loser = (winner == msg.sender) ? game.opponent : msg.sender;

        emit LogGameResolved(session, winner, loser);

        balances[winner] = balances[winner].add(game.bet * 2);
        games[session].bet = 0;

        return true;
    }
    
    function cancel(bytes32 session, bytes32 nonce, Moves move) public returns(bool success) {
        Game memory game = games[session];

        require(game.timelimit > now && game.bet != 0, "Game is over");
        require(hashMove(msg.sender, nonce, move) == session && game.opponentMove == Moves.NONE, "You cannot cancel this game");

        emit LogGameCancelled(session, msg.sender);

        balances[msg.sender] = balances[msg.sender].add(game.bet);
        games[session].bet = 0;

        return true;
    }

    function penalize(bytes32 session) public returns(bool success) {
        Game memory game = games[session];

        require(game.timelimit < now && game.bet != 0, "Game is not over yet");
        require(msg.sender == game.opponent && game.opponentMove != Moves.NONE, "You cannot claim a penality");

        emit LogPlayerPenalized(session, msg.sender);

        balances[msg.sender] = balances[msg.sender].add(game.bet * 2);
        games[session].bet = 0;

        return true;
    }

    function withdraw() public returns(bool success) {
        uint amount = balances[msg.sender];
        
        require(amount > 0, "Nothing to withdraw");
        
        balances[msg.sender] = 0;
        
        emit LogBetWithdrawed(msg.sender, amount);
        
        msg.sender.transfer(amount);
        
        return true;
    }
}