// License-Identifier: MIT
// Tests for Block Miner Game Contracts
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber, Contract } from "ethers";

// eslint-disable-next-line node/no-missing-import
import * as TU from "./TestUtils";

/**
 * Tests for Minting 2x NFT Puzzles
 *
 * @author Rohin Knight
 */
describe("Puzzle2xNFT", () => {
  // Set of tiles to use for creating the puzzle
  const tiles1 = [
    [TU.Tile.SOFT_LADDER, TU.Tile.PICK],
    [TU.Tile.NONE, TU.Tile.NONE],
  ];
  let puzzleObj: TU.Puzzle;
  let nftContract: Contract;
  let nft2xContract: Contract;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;

  const IDS_1 = [1, 1, 1, 1];
  const IDS_2 = [1, 1, 1, 2];
  const SETUP_1 = 0;
  const SETUP_2 = 0;

  // ===================================== Setup and Utils  =====================================

  before(async () => {
    const [owner] = await ethers.getSigners();

    // Deploy PuzzleNFT Contract
    const nftContractFactory = await ethers.getContractFactory("PuzzleNFT");
    nftContract = await upgrades.deployProxy(
      nftContractFactory,
      ["ipfs://example"],
      { kind: "uups" }
    );
    await nftContract.deployed();

    // Create puzzle obj that we can modify and encode for minting
    puzzleObj = new TU.Puzzle();
    puzzleObj.tiles = TU.createExpandedTiles(
      tiles1,
      TU.PUZZLE_W,
      TU.PUZZLE_H,
      TU.Tile.SOFT_BLOCK
    );

    // Mint 4 Puzzles
    nftContract.safeMint(owner.address, encodePuzzle(1));
    nftContract.safeMint(owner.address, encodePuzzle(2));
    nftContract.safeMint(owner.address, encodePuzzle(3));
    nftContract.safeMint(owner.address, encodePuzzle(4));
  });

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();

    // Deploy Puzzle2xNFT Contract
    const nft2xContractFactory = await ethers.getContractFactory("Puzzle2xNFT");
    nft2xContract = await upgrades.deployProxy(
      nft2xContractFactory,
      ["ipfs://example", nftContract.address],
      { kind: "uups" }
    );
    await nft2xContract.deployed();
  });

  function encodePuzzle(variation: number): BigNumber[] {
    puzzleObj.playerX = variation;
    return TU.encodePuzzleTo4u256s(puzzleObj);
  }

  // ========================================== Tests ===========================================

  it("Minted with NewPuzzle event", async () => {
    await expect(nft2xContract.safeMint(owner.address, IDS_1, SETUP_1))
      .to.emit(nft2xContract, "NewPuzzle")
      .withArgs(1);

    await expect(nft2xContract.safeMint(owner.address, IDS_2, SETUP_1))
      .to.emit(nft2xContract, "NewPuzzle")
      .withArgs(2);
  });

  it("Minted to correct addresses", async () => {
    await nft2xContract.safeMint(owner.address, IDS_1, SETUP_1);
    await nft2xContract.safeMint(addr1.address, IDS_2, SETUP_1);
    expect(await nft2xContract.ownerOf(1)).to.equal(owner.address);
    expect(await nft2xContract.ownerOf(2)).to.equal(addr1.address);
  });

  it("Cannot mint if not authorized", async () => {
    await expect(
      nftContract.connect(addr1).safeMint(addr1.address, IDS_1, SETUP_1)
    ).to.be.reverted;
  });

  it("Cannot mint identical puzzles", async () => {
    // Different setup values do not make a different as
    // the puzzle hash is only generated from the IDs
    await nft2xContract.safeMint(owner.address, IDS_1, SETUP_1);
    await expect(
      nft2xContract.safeMint(owner.address, IDS_1, SETUP_2)
    ).to.be.revertedWith("AlreadyMinted");
  });

  // todo: Add same tests used for PuzzleNFT
});
