// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract CardGame is VRFConsumerBaseV2, Ownable {

    //Enums
    enum Suit { Spades, Hearts, Diamonds, Clubs }
    uint8 constant NUM_CARDS = 42; 
    uint8 constant NUM_SUITS = 4;
    uint8 public MAX_POSITION = 10;

    //Structs
    struct Horse {
        uint256 position;
        bool isPlaying;
    }

        struct Card {
        uint8 value;
        Suit suit;
    }

    Card[] public deck;
    Card[] public punishDeck;
    address[] public playerList;

    mapping(address => Suit) public playerSuits;
    mapping(address => Horse) public horses;
    mapping(uint256 => address) private s_rollers;
    mapping(uint256 => bool) private randomWordsFulfilled;
    
    //State Variables
    uint256 public pot;
    bool public gameStarted;
    uint256 public tax = 1; // Impuesto del 1%
    uint256 private suitRequestId;
    uint256 private numberRequestId;
    
    //Chainlink Variables
    uint64 s_suscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 s_keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;

    IERC20 public token;

    //Events
    event DiceRolled(uint256 indexed requestId, address indexed roller);
    event GameEnded(address indexed winner,uint256 prize);
    event TaxBurned(uint256 taxAmount);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);

    constructor(uint64 subscriptionId, address initialOwner) VRFConsumerBaseV2(vrfCoordinator)  Ownable(initialOwner){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_suscriptionId = subscriptionId;
        gameStarted = false;
        playerList = new address[](0);
        token = IERC20(0x420FcA0121DC28039145009570975747295f2329);
    }

    receive() external payable {}

    function enterGame(uint256 amount) public payable {
        require(!gameStarted, "Game has already started");
        require(amount > 0, "Must send Token to enter");
        require(!horses[msg.sender].isPlaying, "Player already entered");
        require(playerList.length < 4, "The game is full");
        require(token.transferFrom(msg.sender, address(this), amount), "La transferencia de tokens fallo");

        pot += amount;
        horses[msg.sender] = Horse({position: 0, isPlaying: true});
        playerSuits[msg.sender] = Suit(playerList.length);
        playerList.push(msg.sender);
    }

   function startGame() public {
        require(playerList.length == 4, "Must have 4 players to start");
        require(!gameStarted, "Game is already in progress");

        gameStarted = true;
        askShuffleCards();
    }


function askShuffleCards() private {
    require(gameStarted, "Game has not started");
    require(horses[msg.sender].isPlaying, "You are not in the game");

    // Verificar si ya se ha realizado la solicitud de los palos de las cartas
    if (suitRequestId == 0) {
        // Solicitar 42 números aleatorios para los palos de las cartas
        suitRequestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_suscriptionId,
            requestConfirmations,
            callbackGasLimit,
            42 // Para obtener los palos de las cartas
        );

        // Registrar el identificador de solicitud con el jugador
        s_rollers[suitRequestId] = msg.sender;

        // Emitir evento para la solicitud de números aleatorios
        emit DiceRolled(suitRequestId, msg.sender);
    } else if (numberRequestId == 0) {
        // Solicitar 10 números aleatorios adicionales para otro propósito
        numberRequestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_suscriptionId,
            requestConfirmations,
            callbackGasLimit,
            10 // Para obtener otros valores que necesitas
        );

        // Registrar el identificador de solicitud con el jugador
        s_rollers[numberRequestId] = msg.sender;

        // Emitir evento para la solicitud de números aleatorios
        emit DiceRolled(numberRequestId, msg.sender);
    } else {
        revert("Both random requests are already made");
    }
}

function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    require(msg.sender == address(COORDINATOR), "Only VRFCoordinator can fulfill");

    address roller = s_rollers[requestId];
    require(roller != address(0), "Roller not found");
    randomWordsFulfilled[requestId] = true;

    // Diferenciar entre los dos tipos de solicitudes
    if (requestId == suitRequestId) {
        // Procesar los valores de las cartas para el deck principal
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint8 cardValue = uint8((randomWords[i] % NUM_CARDS) + 1);
            Suit cardSuit = Suit(randomWords[i] % NUM_SUITS);
            deck.push(Card({value: cardValue, suit: cardSuit}));
        }
    } else if (requestId == numberRequestId) {
        // Procesar los valores de las cartas para el punishDeck
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint8 cardValue = uint8((randomWords[i] % NUM_CARDS) + 1);
            Suit cardSuit = Suit(randomWords[i] % NUM_SUITS);
            punishDeck.push(Card({value: cardValue, suit: cardSuit}));
        }
    }

  // Verificar si ambas solicitudes han sido cumplidas
    if (randomWordsFulfilled[suitRequestId] && randomWordsFulfilled[numberRequestId]) {
        // Si ambas solicitudes han sido cumplidas, iniciar la lógica del juego
        handleGameLogic();
        // Restablecer los identificadores de solicitud para el próximo juego
        suitRequestId = 0;
        numberRequestId = 0;
    }

    // Limpiar el requestId para el próximo rollo
    delete s_rollers[requestId];
    delete randomWordsFulfilled[requestId];
}

function handleGameLogic() private {
    bool allPlayersAdvanced = false;

    // Procesar una carta a la vez del deck principal
    while (deck.length > 0 && !allPlayersAdvanced) {
        Card memory card = deck[deck.length - 1];
        deck.pop();

        // Incrementar la posición de cada jugador si la carta es de su palo
        for (uint256 i = 0; i < playerList.length; i++) {
            address currentPlayer = playerList[i];
            if (playerSuits[currentPlayer] == card.suit) {
                horses[currentPlayer].position += 1;

                // Verificar si el jugador ha ganado
                if (horses[currentPlayer].position >= MAX_POSITION) {
                    endGame(currentPlayer);
                    return; // Salir de la función si hay un ganador
                }
            }
        }

        // Verificar si todos los jugadores han avanzado al menos una posición
        allPlayersAdvanced = true;
        for (uint256 i = 0; i < playerList.length; i++) {
            if (horses[playerList[i]].position == 0) {
                allPlayersAdvanced = false;
                break;
            }
        }

        // Si todos los jugadores han avanzado, aplicar castigo del punishDeck
        if (allPlayersAdvanced && punishDeck.length > 0) {
            Card memory punishmentCard = punishDeck[punishDeck.length - 1];
            punishDeck.pop();

            // Hacer retroceder al jugador correspondiente
            address punishedPlayer = getPlayerBySuit(punishmentCard.suit);
            if (horses[punishedPlayer].position > 1) {
                horses[punishedPlayer].position -= 1;
            }
        }
    }
}

function getPlayerBySuit(Suit suit) private view returns (address) {
    for (uint256 i = 0; i < playerList.length; i++) {
        if (playerSuits[playerList[i]] == suit) {
            return playerList[i];
        }
    }
    revert("No player with this suit");
}

    function endGame(address winner) internal {
        gameStarted = false;
        uint256 prizeBeforeTax = pot;
        uint256 taxAmount = (prizeBeforeTax * tax) / 100;
        uint256 prize = prizeBeforeTax - taxAmount;
        pot = 0;

        // Reinicio de las posiciones de los jugadores
        for (uint256 i = 0; i < playerList.length; i++) {
            horses[playerList[i]].isPlaying = false;
            horses[playerList[i]].position = 0;
        }

        // Quemar el 1% del premio
        require(token.transfer(address(0), taxAmount), "La transferencia de impuesto fallo");
        emit TaxBurned(taxAmount);
        
        // Transferir el premio restante al ganador
        require(token.transfer(winner, prize), "La transferencia de premio fallo");

        emit GameEnded(winner, prize);
    }

    function setTax(uint256 newTax) public onlyOwner {
        tax = newTax;
    }

    function emergencyWithdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
        emit EmergencyWithdrawal(owner(), amount);
    }


}