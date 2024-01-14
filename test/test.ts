import { expect } from "chai";
import { ethers , network} from "hardhat";
import { CardGame } from "../typechain-types/contracts/Contract.sol/CardGame";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { Wallet } from "ethers";

describe("CardGame", function () {
  let cardGame: CardGame;
  let wallet:Wallet
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  let addr4: SignerWithAddress;
  let addressImpersonator: string;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    addressImpersonator = "0x6fCaD30523F0F8648984f3C1b4318e2A16e16824";
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [addressImpersonator]
    });
    const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329";
    const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
    const transferAmount = ethers.parseUnits("200000000", 18); 
    const signer = await ethers.provider.getSigner(addressImpersonator);
    await tokenContract.connect(signer).transfer(owner.address, transferAmount);
    await tokenContract.connect(signer).transfer(addr1.address, transferAmount);
    await tokenContract.connect(signer).transfer(addr2.address, transferAmount);
    await tokenContract.connect(signer).transfer(addr3.address, transferAmount);
    await tokenContract.connect(signer).transfer(addr4.address, transferAmount);
    const cardGameFactory = await ethers.getContractFactory("CardGame", owner);
    cardGame = (await cardGameFactory.deploy(896,owner.address)) as CardGame;
    await cardGame.waitForDeployment(2);
  });

  it("Should deploy and check the owner and status of the game", async function () {

    expect(await cardGame.owner()).to.equal(owner.address);
    expect( await cardGame.gameStarted()).to.equal(false)
  });
  it("Should not let enter player with amount less than minAmount", async function () {
    const entryAmount = ethers.parseUnits("200000000", 18); 
    const signer = await ethers.provider.getSigner(addressImpersonator)
    const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329"
    const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
    const cardGameAddress = cardGame.owner();
    await tokenContract.connect(signer).approve(cardGameAddress, entryAmount);
    await expect(cardGame.connect(signer).enterGame(entryAmount)).to.be.reverted;
  });

    it("Should let enter player with amount more than minAmount", async function () {
        const entryAmount = ethers.parseUnits("200000000", 18);
        const signer = await ethers.provider.getSigner(addressImpersonator)
        const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329"
        const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
        const cardGameAddress = await cardGame.getAddress();
        await tokenContract.connect(signer).approve(cardGameAddress, entryAmount);
        await cardGame.connect(signer).enterGame(entryAmount);
        const playerCount = await cardGame.getPlayerListLength();
        const isPlayerPlaying = (await cardGame.horses(signer.address)).isPlaying;
        expect(playerCount).to.be.above(0)
        expect(isPlayerPlaying).to.be.true;
    });
it("should not let enter a player twice",async function () {
    const entryAmount = ethers.parseUnits("200000000", 18);
    const signer = await ethers.provider.getSigner(addressImpersonator)
    const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329"
    const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
    const cardGameAddress = await cardGame.getAddress();
    await tokenContract.connect(signer).approve(cardGameAddress, entryAmount);
    await cardGame.connect(signer).enterGame(entryAmount);
    await expect(cardGame.connect(signer).enterGame(entryAmount))
        .to.be.revertedWith("Player already entered");
})
it("it should let enter 4 players",async function () {
  const entryAmount = ethers.parseUnits("200000000",18);
  const signer = await ethers.provider.getSigner(addressImpersonator)
  const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329"
  const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
  const cardGameAddress = await cardGame.getAddress();
  await tokenContract.connect(signer).approve(cardGameAddress, entryAmount);
  await tokenContract.connect(addr1).approve(cardGame,entryAmount)
  await tokenContract.connect(addr2).approve(cardGame,entryAmount)
  await tokenContract.connect(addr3).approve(cardGame,entryAmount)
  await cardGame.connect(signer).enterGame(entryAmount);
  await cardGame.connect(addr1).enterGame(entryAmount);
  await cardGame.connect(addr2).enterGame(entryAmount);
  await cardGame.connect(addr3).enterGame(entryAmount);
  const playerCount = await cardGame.getPlayerListLength();
  expect(playerCount).to.equal(4);
})
it("it should start game at 4 people in",async function () {
  const entryAmount = ethers.parseUnits("200000000",18);
  const signer = await ethers.provider.getSigner(addressImpersonator)
  const tokenAddress = "0x420FcA0121DC28039145009570975747295f2329"
  const tokenContract = await ethers.getContractAt("IERC20", tokenAddress);
  const cardGameAddress = await cardGame.getAddress();
  await tokenContract.connect(signer).approve(cardGameAddress, entryAmount);
  await tokenContract.connect(addr1).approve(cardGame,entryAmount)
  await tokenContract.connect(addr2).approve(cardGame,entryAmount)
  await tokenContract.connect(addr3).approve(cardGame,entryAmount)
  await cardGame.connect(signer).enterGame(entryAmount);
  await cardGame.connect(addr1).enterGame(entryAmount);
  await cardGame.connect(addr2).enterGame(entryAmount);
  await cardGame.connect(addr3).enterGame(entryAmount);
  const isGameStarted = await cardGame.gameStarted()
  expect(isGameStarted).to.be.true;
})



});