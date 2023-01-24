// License-Identifier: MIT
// Tests for Block Miner Game Contracts
import { ethers, upgrades } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

// eslint-disable-next-line node/no-missing-import
import * as TU from "./TestUtils";

/**
 * Tests for testing puzzle solutions
 *
 * @author Rohin Knight
 */
describe("Solution Checker", () => {
  let nftContract: Contract;
  let solutionChecker: Contract;

  // Demo puzzle for testing different moves
  const tiles1 = [
    [TU.Tile.NONE, TU.Tile.PICK, TU.Tile.NONE, TU.Tile.NONE],
    [TU.Tile.NONE, TU.Tile.NONE, TU.Tile.SOFT_BLOCK, TU.Tile.SOFT_LADDER],
    [TU.Tile.NONE, TU.Tile.SOFT_BLOCK, TU.Tile.NONE, TU.Tile.PICK],
    [TU.Tile.SOFT_LADDER, TU.Tile.NONE, TU.Tile.SOFT_LADDER, TU.Tile.NONE],
  ];
  let puzzle: TU.Puzzle;
  let moveTypes: TU.MType[];
  let moveDirs: TU.MDir[];
  let owner: SignerWithAddress;

  function addMove(moveType: TU.MType, moveDir: TU.MDir): void {
    moveTypes.push(moveType);
    moveDirs.push(moveDir);
  }

  // ===================================== Setup and Utils  =====================================

  beforeEach(async () => {
    [owner] = await ethers.getSigners();

    // Deploy PuzzleNFT Contract
    const nftContractFactory = await ethers.getContractFactory("PuzzleNFT");
    nftContract = await upgrades.deployProxy(
      nftContractFactory,
      ["ipfs://example"],
      { kind: "uups" }
    );
    await nftContract.deployed();

    // Deploy SolutionChecker Contract
    const solutionCheckerFactory = await ethers.getContractFactory(
      "SolutionChecker"
    );
    solutionChecker = await upgrades.deployProxy(
      solutionCheckerFactory,
      [nftContract.address],
      { kind: "uups" }
    );
    await solutionChecker.deployed();

    puzzle = new TU.Puzzle();
    puzzle.tiles = TU.createExpandedTiles(
      tiles1,
      TU.PUZZLE_W,
      TU.PUZZLE_H,
      TU.Tile.SOFT_BLOCK
    );

    moveTypes = [];
    moveDirs = [];
  });

  async function testSolution() {
    const levelData = TU.encodePuzzleTo4u256s(puzzle);
    await nftContract.safeMint(owner.address, levelData);

    const encodedSolution = TU.getEncodedSolution(moveTypes, moveDirs);
    const setupData = 11; // number with last 3 digits: <target crystals><end pos><start pos>

    await solutionChecker.test2xSolution(
      [1, 1, 1, 1],
      setupData,
      encodedSolution
    );
  }

  // ========================================== Tests ===========================================
  // todo: Add tests
  // - Fall and pickup on start
  // - All types of invalid moves
  // - Invalid puzzle data

  it("Walk right test", async () => {
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);

    puzzle.setPlayer(1, 3);
    puzzle.setExit(3, 3);
    await testSolution();
  });

  it("Fall on solid", async () => {
    addMove(TU.MType.MOVE, TU.MDir.LEFT);

    puzzle.setPlayer(2, 0);
    puzzle.setExit(1, 1);
    await testSolution();
  });

  it("Fall on ladder", async () => {
    addMove(TU.MType.MOVE, TU.MDir.LEFT);
    addMove(TU.MType.MOVE, TU.MDir.DOWN);
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);

    puzzle.setPlayer(1, 1);
    puzzle.setExit(1, 3);
    await testSolution();
  });

  it("Place soft block and climb", async () => {
    addMove(TU.MType.MOVE, TU.MDir.LEFT);
    addMove(TU.MType.MINE, TU.MDir.RIGHT);
    addMove(TU.MType.PLACE_BLOCK, TU.MDir.RIGHT_DOWN);
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);
    addMove(TU.MType.MOVE, TU.MDir.UP);

    puzzle.setPlayer(2, 0);
    puzzle.setExit(3, 0);
    await testSolution();
  });

  it("Place ladder and climb", async () => {
    addMove(TU.MType.MOVE, TU.MDir.RIGHT);
    addMove(TU.MType.MOVE, TU.MDir.LEFT);
    addMove(TU.MType.MOVE, TU.MDir.UP);
    addMove(TU.MType.MINE, TU.MDir.DOWN);
    addMove(TU.MType.MOVE, TU.MDir.LEFT);

    addMove(TU.MType.PLACE_LADDER, TU.MDir.LEFT_UP);
    addMove(TU.MType.MOVE, TU.MDir.LEFT);
    addMove(TU.MType.MOVE, TU.MDir.UP);
    addMove(TU.MType.MOVE, TU.MDir.UP);

    puzzle.setPlayer(2, 2);
    puzzle.setExit(0, 1);
    await testSolution();
  });
});
