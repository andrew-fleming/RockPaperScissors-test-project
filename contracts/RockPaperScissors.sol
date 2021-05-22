pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Rock, paper, scissors game played with ERC20 tokens
/// @author Andrew Fleming
/// @notice Use this contract to create a rock, paper, scissors factory
/// @dev Player moves are not encoded
contract RockPaperScissors {

    struct Game {
        address playerOne;
        address playerTwo;
        uint8 p1Move;
        uint8 p2Move;
        uint32 startTime;
        uint256 _gameId;
        uint256 betAmount;
    }
    
    // userAddress => userBalance
    mapping(address => uint256) public userBalance;
    // gameId => openGame
    mapping(uint256 => bool) public openGame;
    // p1Move => p2Move => isP1Winner
    mapping(uint8 => mapping(uint8 => bool)) public isP1Winner;
    
    uint256 public gameId; // Game identifier

    IERC20 public daiToken; // DAI token instance

    Game[] public games; // Array to store game data
    
    /// @notice Connects to ERC20 interface
    /// @dev isP1Winner mappings set as the only winning combinations in game for player one
    /// @param _daiToken Requisite address for DAI stablecoin
    constructor(IERC20 _daiToken) {
        daiToken = _daiToken;
        isP1Winner[1][3] = true;
        isP1Winner[2][1] = true;
        isP1Winner[3][2] = true;
    }
    
    /// @notice Creates a game instance whereby sender declares the bet amount (including zero)
    /// @dev After creating the struct object, the openGame mapping is set to true and the global 
    ///      gameId increases by one
    /// @param _betAmount The cost to play as chosen by the game maker
    function createGame(uint _betAmount) public {
        require(userBalance[msg.sender] >= _betAmount, 
            "Insufficient funds"
        );
        Game memory game;
        userBalance[msg.sender] -= _betAmount;
        game.betAmount = _betAmount;
        game._gameId = gameId;
        game.playerOne = msg.sender;
        games.push(game);
        openGame[gameId] = true;
        gameId++;
    }

    /// @notice 
    /// @dev 
    /// @param _gameId ghghg
    function joinGame(uint _gameId) public {
        require(
            openGame[_gameId] == true &&
            userBalance[msg.sender] >= games[_gameId].betAmount,
            "Either game is closed or insufficient funds"
        );
        Game storage game = games[_gameId];
        openGame[_gameId] = false;
        game.playerTwo = msg.sender;
        userBalance[msg.sender] -= game.betAmount;
    }

    /// @notice 
    /// @dev 
    /// @param _gameId ghghgh
    /// @param _choice ghghg
    function sendMove(uint256 _gameId, uint8 _choice) public {
        Game storage game = games[_gameId];
        require(
            msg.sender == game.playerOne && game.p1Move == 0 ||
            msg.sender == game.playerTwo && game.p2Move == 0,
            "Either incorrect gameId or move already sent"
        );
        if(msg.sender == game.playerOne){
            game.p1Move = _choice;
        } else {
            game.p2Move = _choice;
        }

        if(game.startTime == 0){
            game.startTime = SafeCast.toUint32(block.timestamp);
\        } else {
            require(game.startTime + 300 >= block.timestamp, "Timed out");
            finishGame(_gameId);
        }
    }

    /// @notice Determines the outcome and updates participating users' balances
    /// @dev The first conditional statement checks if the game is a tie. If not, the contract inserts
    ///      the players' moves into the isP1Winner mapping. If it matches one of the combinations hardcoded
    ///      in the constructor, player one wins
    /// @param _gameId An unsigned integer used to identify specific a game
    function finishGame(uint _gameId) private {
        Game memory game = games[_gameId];
        if(game.p1Move == game.p2Move){
                userBalance[game.playerOne] += game.betAmount;
                userBalance[game.playerTwo] += game.betAmount;
        } else {
            bool res = isP1Winner[game.p1Move][game.p2Move];
            uint256 winAmount = game.betAmount * 2;

            if(res == true) {
                userBalance[game.playerOne] += winAmount;
            } else {
                userBalance[game.playerTwo] += winAmount;
            }
        }
    }

    /// @notice 
    /// @dev 
    /// @param _gameId An unsigned integer used to identify specific a game
    function discardCreatedGame(uint256 _gameId) public {
        require(
            openGame[_gameId] == true &&
            games[_gameId].playerOne == msg.sender,
            "Game not open and/or wrong gameId"
        );
        openGame[_gameId] = false;
        userBalance[msg.sender] += games[_gameId].betAmount;
    }

    /// @notice
    /// @dev
    /// @param _gameId An unsigned integer used to identify specific a game
    function timeOut(uint _gameId) public {
        Game memory game = games[_gameId];
        require(
            game.startTime + 300 < block.timestamp && // Greater than 5 minutes
            msg.sender == game.playerOne || 
            msg.sender == game.playerTwo,
            "Either game did not time out or player not in game"
        );
        uint256 delayFee = game.betAmount / 5;
        if(game.p1Move == 0){
            userBalance[game.playerOne] += delayFee * 4;
            userBalance[game.playerTwo] += game.betAmount + delayFee;
        } else {
            userBalance[game.playerTwo] += delayFee * 4;
            userBalance[game.playerOne] += game.betAmount + delayFee;
        }
    }

    /// @notice Sends the requested DAI amount to the contract which serves as an enrollment to play
    /// @dev Making one ERC20 transaction to play reduces gas fees for the user and allows the user to
    ///      to bet with their winnings as instructed. Further, the contract's custody of the user's funds
    ///      helps enforce the timeout fee for nonresponsive players
    /// @param amount The quantity of DAI to send
    function deposit(uint amount) public {
        require(daiToken.balanceOf(msg.sender) >= amount, "Insufficient funds");
        uint256 toTransfer = amount;
        daiToken.transferFrom(msg.sender, address(this), toTransfer);
        userBalance[msg.sender] += toTransfer;
    }

    /// @notice Sends the requested DAI amount back to the user
    /// @dev 
    /// @param amount The quantity of DAI for the user to receive
    function withdraw(uint amount) public {
        require(userBalance[msg.sender] >= amount, "Insufficient funds");
        userBalance[msg.sender] -= amount;
        daiToken.transfer(msg.sender, amount);
    }

}