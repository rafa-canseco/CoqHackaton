# CardGame Smart Contract

## Description

A Solidity smart contract for a card game using Chainlink VRF for randomness, OpenZeppelin for ERC20 token betting and access control, and a taxation system.

## Features

- ERC20 token betting
- Chainlink VRF integration
- OpenZeppelin's Ownable module
- Game logic with card suits and values
- Taxation with burn mechanism
- Emergency withdrawal function

## How to Play

1. Players bet ERC20 tokens to enter.
2. Game starts with four players.
3. Chainlink VRF shuffles the deck.
4. Players advance by drawing matching suit cards.
5. Winner gets the pot minus taxes.

## Setup

1. Install dependencies:
```shell
npm install @openzeppelin/contracts@4.7.3
npm install @chainlink/contracts@0.4.0
```
2. Deploy with Truffle, Hardhat, or Remix.

## Usage

- `enterGame(uint256 amount)`: Join the game.
- `setTax(uint256 newTax)`: Adjust tax rate (onlyOwner).
- `emergencyWithdraw()`: Owner's emergency fund retrieval.

## Events

- `GameEnded`: When a player wins.
- `TaxBurned`: On tax burning.
- `EmergencyWithdrawal`: Owner's emergency withdrawal.

## License

MIT License.


