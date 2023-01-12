// License-Identifier: MIT
// Tests for Block Miner Game Contracts
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber, Contract } from "ethers";

// eslint-disable-next-line node/no-missing-import
import * as TestUtils from "./TestUtils";

/**
 * Tests for Minting NFT Puzzles
 *
 * @author Rohin Knight
 */
describe("PuzzleNFT", () => {
  // Set of tiles to use for creating the puzzle
  const tiles1 = [
    [TestUtils.Tile.Ladder, TestUtils.Tile.Pickhammer],
    [TestUtils.Tile.None, TestUtils.Tile.None],
  ];
  let puzzleObj: TestUtils.Puzzle;
  let nftContract: Contract;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  const invalidPuzzle = Array(4).fill(BigNumber.from(0));

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

    // Create puzzle obj that we can modify and encode for minting
    puzzleObj = new TestUtils.Puzzle();
    puzzleObj.tiles = TestUtils.createExpandedTiles(
      tiles1,
      TestUtils.PUZZLE_WIDTH,
      TestUtils.PUZZLE_HEIGHT,
      TestUtils.Tile.Soft
    );
  });

  function encodePuzzle(variation: number): BigNumber[] {
    puzzleObj.playerX = variation;
    return TestUtils.encodePuzzleTo4u256s(puzzleObj);
  }

  // ========================================== Tests ===========================================

  it("Minted with NewPuzzle event", async () => {
    await expect(nftContract.safeMint(owner.address, encodePuzzle(1)))
      .to.emit(nftContract, "NewPuzzle")
      .withArgs(1);

    await expect(nftContract.safeMint(owner.address, encodePuzzle(2)))
      .to.emit(nftContract, "NewPuzzle")
      .withArgs(2);
  });

  it("Minted to correct addresses", async () => {
    await nftContract.safeMint(owner.address, encodePuzzle(1));
    await nftContract.safeMint(addr1.address, encodePuzzle(2));
    expect(await nftContract.ownerOf(1)).to.equal(owner.address);
    expect(await nftContract.ownerOf(2)).to.equal(addr1.address);
  });

  it("Cannot mint if not authorized", async () => {
    await expect(
      nftContract.connect(addr1).safeMint(addr1.address, encodePuzzle(1))
    ).to.be.reverted;
  });

  it("Cannot mint identical puzzles", async () => {
    await nftContract.safeMint(owner.address, encodePuzzle(1));
    await expect(
      nftContract.safeMint(owner.address, encodePuzzle(1))
    ).to.be.revertedWith("AlreadyMinted");
  });

  it("Get number of puzzles", async () => {
    expect(await nftContract.totalMinted()).to.equal(0);
    await nftContract.safeMint(owner.address, encodePuzzle(1));
    expect(await nftContract.totalMinted()).to.equal(1);
    await nftContract.safeMint(owner.address, encodePuzzle(2));
    expect(await nftContract.totalMinted()).to.equal(2);
  });

  it("Fetch puzzle", async () => {
    const puzzleData = encodePuzzle(1);
    await nftContract.safeMint(owner.address, puzzleData);
    expect(await nftContract.getPuzzle(1)).to.deep.equal(puzzleData);
  });

  it("Fetch puzzle that does not exist", async () => {
    const fetchedPuzzle: BigNumber[] = await nftContract.getPuzzle(0);
    expect(fetchedPuzzle).to.deep.equal(invalidPuzzle);
  });

  it("Fetch multiple puzzles", async () => {
    const puzzles: BigNumber[][] = [];

    // Mint 4 puzzles
    for (let i = 0; i < 4; ++i) {
      puzzles.push(encodePuzzle(i));
      await nftContract.safeMint(owner.address, puzzles[i]);
    }

    // Fetch puzzle 1
    let fetchedPuzzles = await nftContract.getPuzzles([1]);
    expect(puzzles[0]).to.deep.equal(fetchedPuzzles[0]);

    // Fetch puzzles 1, 2 and 4. Args can be in any order.
    fetchedPuzzles = await nftContract.getPuzzles([2, 1, 4]);
    expect(puzzles[1]).to.deep.equal(fetchedPuzzles[0]);
    expect(puzzles[0]).to.deep.equal(fetchedPuzzles[1]);
    expect(puzzles[3]).to.deep.equal(fetchedPuzzles[2]);

    // Fetch puzzles where two IDs do not exist
    fetchedPuzzles = await nftContract.getPuzzles([0, 2, 5]);
    expect(fetchedPuzzles[0]).to.deep.equal(invalidPuzzle);
    expect(fetchedPuzzles[1]).to.deep.equal(puzzles[1]);
    expect(fetchedPuzzles[2]).to.deep.equal(invalidPuzzle);
  });

  it("Mint with default URIs", async () => {
    await nftContract.safeMint(owner.address, encodePuzzle(1));
    await nftContract.safeMint(owner.address, encodePuzzle(2));
    expect(await nftContract.tokenURI(1)).to.equal("ipfs://example");
    expect(await nftContract.tokenURI(2)).to.equal("ipfs://example");
  });

  it("Set token URI", async () => {
    const CID_1 = "QmUNLLsAAAAz5vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn";
    await nftContract.safeMint(owner.address, encodePuzzle(1));
    await nftContract.setCIDs([CID_1]);
    expect(await nftContract.tokenURI(1)).to.equal(`ipfs://${CID_1}`);
  });

  it("Set multiple token URIs", async () => {
    const puzzle1 = encodePuzzle(1);
    const puzzle2 = encodePuzzle(2);
    const puzzle3 = encodePuzzle(3);

    const CID_1 = "QmUNLLsAAAAz5vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn";
    const CID_2 = "QmUNLLsBBBBz5vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn";
    const CID_3 = "QmUNLLsCCCCz5vLxQVkXqqLX5R1X375qqfHbsf67hvA3Nn";
    await nftContract.safeMint(owner.address, puzzle1);
    await nftContract.setCIDs([CID_1]);
    expect(await nftContract.tokenURI(1)).to.equal(`ipfs://${CID_1}`);

    await nftContract.safeMint(owner.address, puzzle2);
    await nftContract.safeMint(owner.address, puzzle3);
    await nftContract.setCIDs([CID_2, CID_3]);
    expect(await nftContract.tokenURI(2)).to.equal(`ipfs://${CID_2}`);
    expect(await nftContract.tokenURI(3)).to.equal(`ipfs://${CID_3}`);
  });

  it("Get puzzle Id for data", async () => {
    const puzzle1 = encodePuzzle(1);
    const puzzle2 = encodePuzzle(2);
    await nftContract.safeMint(owner.address, puzzle1);
    expect(await nftContract.getPuzzleId(puzzle1)).to.equal(1);
    expect(await nftContract.getPuzzleId(puzzle2)).to.equal(0); // 0 = no puzzle minted for data
  });

  it("Test sending data smaller than 4 or larger than 4", async () => {
    const data = new Array(3).fill(BigNumber.from("0"));
    await expect(nftContract.safeMint(owner.address, data)).to.be.reverted;
  });

  it("Test sending data larger than 4", async () => {
    const data = new Array(5).fill(BigNumber.from("0"));
    await expect(nftContract.safeMint(owner.address, data)).to.be.reverted;
  });
});
