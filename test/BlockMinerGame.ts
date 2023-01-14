// License-Identifier: MIT
// Tests for Block Miner Game Contracts
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber, Contract, utils } from "ethers";

// eslint-disable-next-line node/no-missing-import
import * as TU from "./TestUtils";

const MINTER_ROLE = utils.keccak256(utils.toUtf8Bytes("MINTER_ROLE"));

/**
 * Tests for Block Miner Game contract
 *
 * @author Rohin Knight
 */
describe("BlockMinerGame", () => {
  // Set of tiles to use for creating the puzzle
  const tiles1 = [
    [TU.Tile.SOFT_LADDER, TU.Tile.PICK],
    [TU.Tile.NONE, TU.Tile.NONE],
  ];
  let puzzleObj: TU.Puzzle;
  let nftContract: Contract;
  let nft2xContract: Contract;
  let gameContract: Contract;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;

  // ===================================== Setup and Utils  =====================================

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();

    // Deploy PuzzleNFT Contract
    const nftContractFactory = await ethers.getContractFactory("PuzzleNFT");
    nftContract = await upgrades.deployProxy(
      nftContractFactory,
      ["ipfs://example"],
      { kind: "uups" }
    );
    await nftContract.deployed();

    // Deploy Puzzle2xNFT Contract
    const nft2xContractFactory = await ethers.getContractFactory("Puzzle2xNFT");
    nft2xContract = await upgrades.deployProxy(
      nft2xContractFactory,
      ["ipfs://example", nftContract.address],
      { kind: "uups" }
    );
    await nft2xContract.deployed();

    // Deploy BlockMinerGame Contract
    const gameContractFactory = await ethers.getContractFactory("BlockMinerGame");
    gameContract = await upgrades.deployProxy(
      gameContractFactory,
      [nftContract.address, nft2xContract.address],
      { kind: "uups" }
    );
    await gameContract.deployed();

    // Grant minting rights to BlockMinerGame Contract
    await nftContract.grantRole(MINTER_ROLE, gameContract.address);
    await nft2xContract.grantRole(MINTER_ROLE, gameContract.address);

    // Create puzzle obj that we can modify and encode for minting
    puzzleObj = new TU.Puzzle();
    puzzleObj.tiles = TU.createExpandedTiles(
      tiles1,
      TU.PUZZLE_W,
      TU.PUZZLE_H,
      TU.Tile.SOFT_BLOCK
    );
  });

  function encodePuzzle(variation: number): BigNumber[] {
    puzzleObj.playerX = variation;
    return TU.encodePuzzleTo4u256s(puzzleObj);
  }

  function eth(value: number): BigNumber {
    return ethers.utils.parseEther(value.toString());
  }

  // ========================================== Tests ===========================================

  // todo: Write tests for
  // 1. Reentrancy attack tests for all withdraw functions

  it("Non-owner can mint via game contract", async () => {
    await expect(
      gameContract.connect(addr1).safeMint(encodePuzzle(1), {
        value: eth(0),
      })
    )
      .to.emit(nftContract, "NewPuzzle")
      .withArgs(1);
  });

  it("Set mint fees", async () => {
    await gameContract.setMintFees(
      eth(0.01), // dev fee
      eth(0.02), // rewards fee
      eth(0.01) // puzzle fee
    );
    expect(await gameContract.nftMintFee()).to.equal(eth(0.03));
    expect(await gameContract.bigNftMintFee()).to.equal(eth(0.04));
  });

  it("Pay mint fee", async () => {
    await gameContract.setMintFees(
      eth(0.01), // dev fee
      eth(0.02), // rewards fee
      eth(0.01) // puzzle fee
    );
    await gameContract.safeMint(encodePuzzle(1), {
      value: eth(0.03),
    });
    await gameContract.safeMint(encodePuzzle(2), {
      value: eth(0.03),
    });

    expect(await gameContract.ownerBalance()).to.equal(eth(0.02));
    expect(await gameContract.rewardsBalance()).to.equal(eth(0.04));
  });

  it("Deposit and withdraw bond", async () => {
    const bondDeposit = eth(0.01);
    await gameContract.depositBond({ value: bondDeposit });
    expect(await gameContract.bondBalance()).to.equal(bondDeposit);
    await gameContract.withdrawBond(); // todo: Confirm amount received
    expect(await gameContract.bondBalance()).to.equal(0);
  });

  it("Withdraw NFT Royalty", async () => {
    await gameContract.setMintFees(
      eth(0), // dev fee
      eth(0), // rewards fee
      eth(0.01) // per puzzle fee
    );
    await gameContract.safeMint(encodePuzzle(1));
    await gameContract.safeMint(encodePuzzle(2));
    await gameContract.safeMint2x([1, 1, 1, 2], 0, {
      value: eth(0.04),
    });

    expect(await gameContract.nftBalance(1)).to.equal(eth(0.03));
    await gameContract.nftWithdraw(1); // todo: Confirm amount received
    expect(await gameContract.nftBalance(1)).to.equal(eth(0));
  });
});
