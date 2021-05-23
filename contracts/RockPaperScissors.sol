pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Rock, paper, scissors game played with ERC20 tokens
/// @author Andrew Fleming
/// @notice Use this contract to play rock, paper, scissors while betting with DAI stablecoin
/// @dev Game factory. Player moves are not encoded
contract RockPaperScissors {

    struct Game {
        address playerOne;
        address playerTwo;
        uint8 p1Move;
        uint8 p2Move;
        uint256 startTime;
        uint256 _gameId;
        uint256 betAmount;
    }
    
    // userAddress => userBalance
    mapping(address => uint256) public userBalance;
    // gameId => openGame
    mapping(uint256 => bool) public openGame;
    // gameId => gameFinished
    mapping(uint256 => bool) public gameFinished;
    // p1Move => p2Move => isP1Winner
    mapping(uint8 => mapping(uint8 => bool)) public isP1Winner;
    
    uint256 public gameId; // Game identifier

    IERC20 public daiToken; // DAI state variable

    Game[] public games; // Array to store game data

    event Outcome(uint256 indexed gameId, address indexed winner); // Sole event created for testing
    
    /// @notice Connects to ERC20 interface
    /// @dev isP1Winner mapping sets the only winning combinations in the game for player one.
    ///      Other combinations equate to false; ergo, player two wins. The finishGame function
    ///      evaluates for draws prior to utilizing isP1Winner
    /// @param _daiToken Requisite address for DAI stablecoin
    constructor(IERC20 _daiToken) {
        daiToken = _daiToken;
        isP1Winner[1][3] = true;
        isP1Winner[2][1] = true;
        isP1Winner[3][2] = true;
    }
    
    /// @notice Creates a game instance whereby the user declares the bet amount (including zero)
    /// @dev After creating the struct object, the openGame mapping is set to true and the state 
    ///      variable gameId increases by one
    /// @param _betAmount The cost to play(can be zero) as chosen by the caller
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

    /// @notice The next step after createGame in the game's lifecycle. This function is for users
    ///         who want to play without creating their own game or want to join a particular user's
    ///         game (as long as they know their gameId)
    /// @dev Assigns the joining player's address into the Game struct as well as removing the
    ///      bet amount from their balance. This incentivizes users to participate in the games
    ///      they join. The openGame mapping is assigned to false. This prevents other users from
    ///      overriding the initial joiner as checked by the require statement
    /// @param _gameId An unsigned integer used to identify specific a game
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

    /// @notice Sends the user's choice of rock, paper, or scissors to the contract. If the
    ///         user is first to send his/her move, the five minute timer begins. Otherwise,
    ///         the contract compares both players' moves and updates their DAI balances
    ///         accordingly
    /// @dev The first conditional statement assigns the user's move to the Game struct. Thereafter,
    ///      it evaluates if the startTime timer was declared. If so, the contract calls the 
    ///      private finishGame function. If the timer equates to zero, however, the contract
    ///      assigns it to the current timestamp
    /// @param _gameId An unsigned integer used to identify specific a game
    /// @param _move The user's choice of rock, paper, or scissors
    function sendMove(uint256 _gameId, uint8 _move) public {
        Game storage game = games[_gameId];
        require(
            gameFinished[_gameId] == false &&
            msg.sender == game.playerOne && game.p1Move == 0 ||
            msg.sender == game.playerTwo && game.p2Move == 0,
            "Either incorrect gameId, move already sent, or game finished"
        );
        if(msg.sender == game.playerOne){
            game.p1Move = _move;
        } else {
            game.p2Move = _move;
        }

        if(game.startTime == 0){
            game.startTime = block.timestamp;
        } else {
            require(game.startTime + 300 >= block.timestamp, "Timed out");
            finishGame(_gameId);
            gameFinished[_gameId] = true;
        }
    }

    /// @notice Determines the outcome and updates participating users' balances
    /// @dev The first conditional statement checks if the game is a tie. If not, the contract inserts
    ///      the players' moves into the isP1Winner mapping. If it matches one of the combinations hardcoded
    ///      in the constructor, player one's userBalance increases by 2x the bet. Otherwise,
    ///      player two's balance is updated
    /// @param _gameId An unsigned integer used to identify specific a game
    function finishGame(uint _gameId) private {
        Game memory game = games[_gameId];
        if(game.p1Move == game.p2Move){
                userBalance[game.playerOne] += game.betAmount;
                userBalance[game.playerTwo] += game.betAmount;
                emit Outcome(_gameId, address(0));
        } else {
            bool res = isP1Winner[game.p1Move][game.p2Move]; 
            uint256 winAmount = game.betAmount * 2;

            if(res == true) {
                userBalance[game.playerOne] += winAmount;
                emit Outcome(_gameId, game.playerOne);
            } else {
                userBalance[game.playerTwo] += winAmount;
                emit Outcome(_gameId, game.playerTwo);
            }
        }
    }

    /// @notice Should be used when a player does not want to keep his/her game open while
    ///         waiting for an opponent
    /// @dev Updates the openGame mapping to false which blocks users from joining this particular game.
    ///      Further, the user receives their bet amount back in the balance. Finally, the gameFinished
    ///      mapping updates to true; as, this prevents users from calling the sendMove function
    ///      to the discarded game's gameId
    /// @param _gameId An unsigned integer used to identify specific a game
    function discardCreatedGame(uint256 _gameId) public {
        require(
            openGame[_gameId] == true &&
            games[_gameId].playerOne == msg.sender,
            "Game not open and/or wrong gameId"
        );
        openGame[_gameId] = false;
        userBalance[msg.sender] += games[_gameId].betAmount;
        gameFinished[_gameId] = true;
    }

    /// @notice Serves as a deterrent for uncooperative players. The active player can call
    ///         this function five minutes after sending their move. The uncooperative player
    ///         receives 80% of his/her bet and the active player receives 120%
    /// @dev Despite the potential for a 15 second discrepancy in the timestamp, 300 seconds
    ///      (5 minutes) seems reasonable for this instance
    /// @param _gameId An unsigned integer used to identify specific a game
    function timeOut(uint _gameId) public {
        Game memory game = games[_gameId];
        require(
            gameFinished[_gameId] == false &&
            msg.sender == game.playerOne || 
            msg.sender == game.playerTwo,
            "Either player not in game or game is finished"
        );
        require(game.startTime + 300 < block.timestamp, "Time not exceeded");
        uint256 delayFee = game.betAmount / 5;
        if(game.p1Move == 0){
            userBalance[game.playerOne] += delayFee * 4;
            userBalance[game.playerTwo] += game.betAmount + delayFee;
        } else {
            userBalance[game.playerTwo] += delayFee * 4;
            userBalance[game.playerOne] += game.betAmount + delayFee;
        }
        gameFinished[_gameId] = true;
    }

    /// @notice Sends the requested DAI amount to the contract which serves as an enrollment to play
    /// @dev Making one ERC20 transaction to play reduces gas fees for the user and allows the user
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
    /// @dev Updates userBalance mapping and sends a transaction with the amount to the user
    /// @param amount The quantity of DAI for the user to receive
    function withdraw(uint amount) public {
        require(userBalance[msg.sender] >= amount, "Insufficient funds");
        userBalance[msg.sender] -= amount;
        daiToken.transfer(msg.sender, amount);
    }
}
