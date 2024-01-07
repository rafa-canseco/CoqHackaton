// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract CardGame is VRFConsumerBaseV2, Ownable {

    //Enums
    enum Suit { Spades, Hearts, Diamonds, Clubs }
    uint8 constant NUM_CARDS = 13; 
    uint8 constant NUM_SUITS = 4;
    uint8 public MAX_POSITION = 50;

    //Structs
    struct Player {
        uint256 position;
        bool isPlaying;
    }

    mapping(address => Player) public players;
    mapping(uint256 => address) private s_rollers;
    mapping(address => uint256) private s_results;
    
    //State Variables
    address _owner;
    address[] public playerList;
    uint256 public pot;
    bool public gameStarted;
    uint256 public tax = 1; // Impuesto del 1%
    
    //Chainlink Variables
    uint64 s_suscriptionId;
    address s_owner;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 s_keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;
    uint32 numRequests =  2;

    IERC20 public token;

    //Events
    event DiceRolled(uint256 indexed requestId, address indexed roller);
    event DiceLanded(uint256 indexed requestId, uint256 indexed result);
    event GameEnded(address indexed winner,uint256 prize);
    event TaxBurned(uint256 taxAmount);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);

    constructor(uint64 subscriptionId, address initialOwner) VRFConsumerBaseV2(vrfCoordinator)  Ownable(initialOwner){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_suscriptionId = subscriptionId;
        gameStarted = false;
        token = IERC20(0x420FcA0121DC28039145009570975747295f2329);
    }

    receive() external payable {}

    function enterGame(uint256 amount) public payable {
        require(!gameStarted, "Game has already started");
        require(amount > 0, "Must send Token to enter");
        require(!players[msg.sender].isPlaying, "Player already entered");

        require(token.transferFrom(msg.sender, address(this), amount), "La transferencia de tokens fallo");

        pot += amount;
        players[msg.sender] = Player({position: 0, isPlaying: true});
        playerList.push(msg.sender);
    }

    function startGame() public {
        require(playerList.length >= 2, "Not enough players");
        require(!gameStarted, "Game is already in progress");

        gameStarted = true;
    }

    function drawCard() public returns (uint256 requestId) {
        require(gameStarted, "Game has not started");
        require(players[msg.sender].isPlaying, "You are not in the game");
        require(s_results[msg.sender] == 0,"Already rolled");

        //We ask for the random Number
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_suscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numRequests
        );

        //assign the request Id to the player in turn
        s_rollers[requestId] = msg.sender;
        emit DiceRolled(requestId, msg.sender);
    }

    // Función de devolución de llamada utilizada por el coordinador de VRF para entregar los números aleatorios
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(msg.sender == address(COORDINATOR), "Only VRFCoordinator can fulfill");

        uint256 cardValue = (randomWords[0] % NUM_CARDS) + 1;
        uint suitValue = (randomWords[1] % NUM_SUITS) + 1;

        uint256 suitMultiplier;
        if (suitValue == 1) {
            suitMultiplier = 2;
        } else if (suitValue == 2) {
            suitMultiplier = 3;
        } else if (suitValue == 3) {
            suitMultiplier = 4;
        } else if (suitValue == 4) {
            suitMultiplier = 5;
        }

        uint256 movement = cardValue * suitMultiplier;

        address player = s_rollers[requestId];
        s_results[player] = movement;

        // Actualizar la posición del jugador con el valor de la carta
        players[player].position += movement;

        // Emitir el evento
        emit DiceLanded(requestId, movement);

        // Verificar si hay un ganador
        if (players[player].position >= MAX_POSITION) {
            endGame(player);
        }
    }

    function endGame(address winner) internal {
        gameStarted = false;
        uint256 prizeBeforeTax = pot;
        uint256 taxAmount = (prizeBeforeTax * tax) / 100;
        uint256 prize = prizeBeforeTax - taxAmount;
        pot = 0;

        // Reinicio de las posiciones de los jugadores
        for (uint256 i = 0; i < playerList.length; i++) {
            players[playerList[i]].isPlaying = false;
            players[playerList[i]].position = 0;
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

    function setMaxPosition(uint8 newMaxPosition) public onlyOwner {
        MAX_POSITION = newMaxPosition;
    }

    function emergencyWithdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
        emit EmergencyWithdrawal(owner(), amount);
    }


}