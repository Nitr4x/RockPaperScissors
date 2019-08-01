pragma solidity 0.5.10;

import "@openzeppelin/contracts/lifecycle/Pausable.sol";

import "./RockPaperScissors.sol";

contract Factory is Pausable {
    event LogGameCreated(address indexed creator, bytes32 name, address game);

    mapping(bytes32 => address) public games;

    function create(bytes32 name, address player1, address player2, uint deadline, uint bet) public whenNotPaused returns(address game) {
        require(name != 0, "Invalid name");

        RockPaperScissors instance = new RockPaperScissors(player1, player2, deadline, bet);

        emit LogGameCreated(msg.sender, name, address(instance));

        games[name] = address(instance);

        return address(instance);
    }
}