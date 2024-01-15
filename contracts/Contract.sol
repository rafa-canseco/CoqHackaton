// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// CardGame contract inherits VRFConsumerBaseV2 for randomness and Ownable for access control
contract CardGame is VRFConsumerBaseV2, Ownable {

    //Enums
    enum Suit { Spades, Hearts, Diamonds, Clubs } // Represents card suits
    uint8 constant NUM_CARDS = 42; // Total number of cards
    uint8 constant NUM_SUITS = 4; // Total number of suits
    uint8 public MAX_POSITION = 10; // Maximum position a horse can reach

    //Structs
    struct Horse {
        uint256 position; // Current position of the horse
        bool isPlaying; // Whether the horse is in the game
    }

    struct Card {
        uint8 value; // Value of the card
        Suit suit; // Suit of the card
    }

    Card[] public deck; // Main deck of cards
    Card[] public punishDeck; // Deck used for penalties
    address[] public playerList; // List of players in the game

    mapping(address => Suit) public playerSuits; // Player's assigned suit
    mapping(address => Horse) public horses; // Player's horse in the game
    mapping(uint256 => address) private s_rollers; // Maps request IDs to players
    mapping(uint256 => bool) private randomWordsFulfilled; // Tracks if randomness was fulfilled
    
    //State Variables
    uint256 public pot; // Total pot of the game
    bool public gameStarted; // Indicates if the game has started
    uint256 public tax = 12; // Tax rate of 12% to be burned
    uint256 public developentTax = 3; //tax for continous development
    address public dev_wallet;
    uint256 private suitRequestId; // Request ID for suit randomness
    uint256 private numberRequestId; // Request ID for number randomness
    uint256 minimumEntry = 100000000; // MinAmount to play
    
    //Chainlink Variables
    uint64 s_suscriptionId; // Chainlink subscription ID
    VRFCoordinatorV2Interface COORDINATOR; // Chainlink VRF Coordinator
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610; // Address of the VRF Coordinator
    bytes32 s_keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61; // Key hash for randomness request
    uint32 callbackGasLimit = 2500000; // Gas limit for the callback function
    uint16 requestConfirmations = 3; // Number of confirmations for randomness request

    IERC20 public token; // ERC20 token used for betting

    //Events
    event DiceRolled(uint256 indexed requestId, address indexed roller); // Emitted when dice is rolled
    event GameEnded(address indexed winner,uint256 prize); // Emitted when game ends
    event TaxBurned(uint256 taxAmount); // Emitted when tax is burned
    event EmergencyWithdrawal(address indexed owner, uint256 amount); // Emitted on emergency withdrawal

    // Constructor sets up the VRFConsumerBaseV2 and Ownable with initial parameters
    constructor(uint64 subscriptionId, address initialOwner) VRFConsumerBaseV2(vrfCoordinator)  Ownable(initialOwner){
        s_suscriptionId = subscriptionId;
        gameStarted = false;
        playerList = new address[](0);
        token = IERC20(0x420FcA0121DC28039145009570975747295f2329);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        dev_wallet = initialOwner;
    }

    receive() external payable {}
    


    // Allows a player to enter the game by transferring the required token amount
    function enterGame(uint256 amount) public payable {
        require(!gameStarted, "Game has already started");
        require(amount >= minimumEntry, "Must send at least 1git 00,000,000 tokens to enter");
        require(!horses[msg.sender].isPlaying, "Player already entered");
        require(playerList.length < 4, "The game is full");
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        pot += amount;
        horses[msg.sender] = Horse({position: 0, isPlaying: true});
        playerSuits[msg.sender] = Suit(playerList.length);
        playerList.push(msg.sender);
        if (playerList.length == 4) {
            gameStarted = true;
        }
    }

   // Starts the game if there are 4 players and the game hasn't started yet
   function startGame() internal {
        require(playerList.length == 4, "Must have 4 players to start");
        require(!gameStarted, "Game is already in progress");

        gameStarted = true;
        askShuffleCards();
    }

   // Requests randomness for shuffling cards and assigns request IDs
function askShuffleCards() private {
    require(gameStarted, "Game has not started");

    // Check if suit randomness request has been made
    if (suitRequestId == 0) {
        // Request randomness for card suits
        suitRequestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_suscriptionId,
            requestConfirmations,
            callbackGasLimit,
            42 // Number of suits to shuffle
        );

        // Register the request ID with the player
        s_rollers[suitRequestId] = msg.sender;

        // Emit event for randomness request
        emit DiceRolled(suitRequestId, msg.sender);
    } else if (numberRequestId == 0) {
        // Request randomness for additional numbers
        numberRequestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_suscriptionId,
            requestConfirmations,
            callbackGasLimit,
            10 // Number of additional values needed
        );

        // Register the request ID with the player
        s_rollers[numberRequestId] = msg.sender;

        // Emit event for randomness request
        emit DiceRolled(numberRequestId, msg.sender);
    } else {
        revert("Both random requests are already made");
    }
}

   // Callback function for Chainlink VRF, processes randomness and starts game logic if both requests are fulfilled
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    require(msg.sender == address(COORDINATOR), "Only VRFCoordinator can fulfill");

    address roller = s_rollers[requestId];
    require(roller != address(0), "Roller not found");
    randomWordsFulfilled[requestId] = true;

    // Differentiate between suit and number randomness requests
    if (requestId == suitRequestId) {
        // Process card values for the main deck
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint8 cardValue = uint8((randomWords[i] % NUM_CARDS) + 1);
            Suit cardSuit = Suit(randomWords[i] % NUM_SUITS);
            deck.push(Card({value: cardValue, suit: cardSuit}));
        }
    } else if (requestId == numberRequestId) {
        // Process card values for the punishDeck
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint8 cardValue = uint8((randomWords[i] % NUM_CARDS) + 1);
            Suit cardSuit = Suit(randomWords[i] % NUM_SUITS);
            punishDeck.push(Card({value: cardValue, suit: cardSuit}));
        }
    }

    // Check if both randomness requests have been fulfilled
    if (randomWordsFulfilled[suitRequestId] && randomWordsFulfilled[numberRequestId]) {
        // Start game logic if both requests are fulfilled
        handleGameLogic();
        // Reset request IDs for the next game
        suitRequestId = 0;
        numberRequestId = 0;
    }

    // Clean up the requestId for the next roll
    delete s_rollers[requestId];
    delete randomWordsFulfilled[requestId];
}

   // Handles the game logic, advancing players and applying penalties
function handleGameLogic() private {
    bool allPlayersAdvanced = false;

    // Process one card at a time from the main deck
    while (deck.length > 0 && !allPlayersAdvanced) {
        Card memory card = deck[deck.length - 1];
        deck.pop();

        // Increment player's position if the card matches their suit
        for (uint256 i = 0; i < playerList.length; i++) {
            address currentPlayer = playerList[i];
            if (playerSuits[currentPlayer] == card.suit) {
                horses[currentPlayer].position += 1;

                // Check if the player has won
                if (horses[currentPlayer].position >= MAX_POSITION) {
                    endGame(currentPlayer);
                    return; // Exit the function if there's a winner
                }
            }
        }

        // Check if all players have advanced at least one position
        allPlayersAdvanced = true;
        for (uint256 i = 0; i < playerList.length; i++) {
            if (horses[playerList[i]].position == 0) {
                allPlayersAdvanced = false;
                break;
            }
        }

        // Apply penalty from punishDeck if all players have advanced
        if (allPlayersAdvanced && punishDeck.length > 0) {
            Card memory punishmentCard = punishDeck[punishDeck.length - 1];
            punishDeck.pop();

            // Move the corresponding player back
            address punishedPlayer = getPlayerBySuit(punishmentCard.suit);
            if (horses[punishedPlayer].position > 1) {
                horses[punishedPlayer].position -= 1;
            }
        }
    }
}

   // Returns the player associated with a given suit
function getPlayerBySuit(Suit suit) private view returns (address) {
    for (uint256 i = 0; i < playerList.length; i++) {
        if (playerSuits[playerList[i]] == suit) {
            return playerList[i];
        }
    }
    revert("No player with this suit");
}

    // Ends the game, distributes the prize, and resets the game state
    function endGame(address winner) internal {
        gameStarted = false;
        uint256 prizeBeforeTax = pot;
        uint256 taxAmount = (prizeBeforeTax * tax) / 100;
        uint256 devTax = (prizeBeforeTax * developentTax) / 100;
        uint256 prize = prizeBeforeTax - taxAmount - devTax;
        pot = 0;

        // Reset player positions for the next game
        for (uint256 i = 0; i < playerList.length; i++) {
            horses[playerList[i]].isPlaying = false;
            horses[playerList[i]].position = 0;
        }

        // Burn the tax amount
        require(token.transfer(address(0), taxAmount), "Tax transfer failed");
        emit TaxBurned(taxAmount);
        
        // Transfer the remaining prize to the winner
        require(token.transfer(winner, prize), "Prize transfer failed");

        // Transfer the dev tax to the dev wallet
        require(token.transfer(dev_wallet, devTax), "Prize transfer failed");

        emit GameEnded(winner, prize);
    }

    // Allows the owner to set a new tax rate
    function setTaxToBurn(uint256 newTax) public onlyOwner {
        tax = newTax;
    }

    // Allows the owner to withdraw funds in case of emergency
    function emergencyWithdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
        emit EmergencyWithdrawal(owner(), amount);
    }

    function getPlayerListLength() public view returns (uint) {
    return playerList.length;
}


}
