pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {

    struct Game {
        address playerOne;
        address playerTwo;
        PlayerChoice pOneChoice;
        PlayerChoice pTwoChoice;
        uint32 startTime;
        uint256 _gameId;
        uint256 betAmount;
    }

    enum PlayerChoice { FORFEIT, ROCK, PAPER, SCISSORS }
    PlayerChoice choice;
    PlayerChoice constant defaultMove = PlayerChoice.FORFEIT;
    
    // userAddress => userBalance
    mapping(address => uint256) public userBalance;
    // gameId => openGame
    mapping(uint256 => bool) public openGame;
    
    uint256 public gameId;

    IERC20 public daiToken;

    Game[] public games;
    
    constructor(IERC20 _daiToken) {
        daiToken = _daiToken;
    }
    
    function createGame(uint _betAmount) public {
        require(userBalance[msg.sender] >= _betAmount, 
            "Insufficient funds"
        );
        Game memory newGame;
        userBalance[msg.sender] -= _betAmount;
        newGame.betAmount = _betAmount;
        newGame._gameId = gameId;
        newGame.playerOne = msg.sender;
        games.push(newGame);
        openGame[gameId] = true;
        gameId++;
    }

    function discardCreatedGame(uint256 _gameId) public {
        require(
            openGame[_gameId] == true &&
            games[_gameId].playerOne == msg.sender,
            "Game not open and/or wrong gameId"
        );
        openGame[_gameId] = false;
        userBalance[msg.sender] += games[_gameId].betAmount;
    }

    function deposit(uint amount) public {
        require(daiToken.balanceOf(msg.sender) >= amount, "Insufficient funds");
        uint256 toTransfer = amount;
        daiToken.transferFrom(msg.sender, address(this), toTransfer);
        userBalance[msg.sender] += toTransfer;
    }

    function withdraw(uint amount) public {
        require(userBalance[msg.sender] >= amount, "Insufficient funds");
        userBalance[msg.sender] -= amount;
        daiToken.transfer(msg.sender, amount);
    }
    
    function joinGame(uint _gameId) public {
        require(
            openGame[_gameId] == true &&
            userBalance[msg.sender] >= games[_gameId].betAmount,
            "Either game is closed or insufficient funds"
        );
        openGame[_gameId] = false;
        games[_gameId].playerTwo = msg.sender;
        userBalance[msg.sender] -= games[_gameId].betAmount;
    }
    
    //function sendChoice() {
    //    
    //}
    //
    //function dispute() {
    //    
    //}

}