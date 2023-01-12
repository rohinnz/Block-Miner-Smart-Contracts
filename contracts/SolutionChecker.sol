// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Open Zeppelin Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Local Contracts
import "./PuzzleNFT.sol";

// todo:
// 1. Add more tests to ensure enough coverage.
// 2. Then optimise for cheaper gas costs
//    a. Use storage and memory correctly
//    a. Use unchecked
//    b. Check if shift operator cheaper than mods

error NoTileToPlace(uint8 tile, uint8 atX, uint8 atY);
error CannotPlace(uint8 tile, uint8 atX, uint8 atY);
error CannotMoveUp(uint8 toX, uint toY);
error NoPicks(uint8 playerX, uint playerY);
error NothingToMine(uint8 atX, uint8 atY);
error MovedIntoSolid(uint8 playerX, uint playerY);
error NotEnoughCrystals(uint8 crystals, uint8 targetCrystals);
error NotAtExit(uint8 playerX, uint playerY);

/**
 * @title Solution checker contract for Puzzle NFTs
 * @notice This is contract is very expensive to run as a transaction.
 * In order to use this on L1, we need to use an optimistic approach.
 *
 * Optimisitc Approach:
 * The user deposits a bond before they are allowed to submit a solution. They then
 * need to wait an hour before they can claim their reward and withdraw their bond.
 * The bond will be more than enough to cover the gas costs to test the solution.
 * If another user discovers the solution is invalid within the hour, they can claim
 * the other user's bond by testing the solution.
 *
 * @author Rohin Knight
 */
contract SolutionChecker is Initializable, OwnableUpgradeable, UUPSUpgradeable {
	uint256 public constant MOD_LIMIT = 10 ** 77 - 1;

	// Level sizes
	uint8 public constant PUZZLE_W = 20;
	uint8 public constant PUZZLE_H = 14;
	uint8 public constant PUZZLE_W_2X = PUZZLE_W * 2;
	uint8 public constant PUZZLE_H_2X = PUZZLE_H * 2;

	// Tile types 0-9
	uint8 public constant NONE = 0;
	uint8 public constant SOFT_BLOCK = 1;
	uint8 public constant HARD_BLOCK = 2;
	uint8 public constant SOFT_LADDER = 3;
	uint8 public constant HARD_LADDER = 4;
	uint8 public constant PICK = 5;

	// Tile types not encoded in u256s
	uint8 public constant CRYSTAL = 10;

	// Move types
	uint8 public constant MOVE = 0;
	uint8 public constant MINE = 1;
	uint8 public constant PLACE_BLOCK = 2;
	uint8 public constant PLACE_LADDER = 3;

	// Move directions
	uint8 public constant RIGHT = 1;
	uint8 public constant LEFT = 2;
	uint8 public constant UP = 3;
	uint8 public constant DOWN = 4;
	uint8 public constant RIGHT_UP = 5;
	uint8 public constant RIGHT_DOWN = 6;
	uint8 public constant LEFT_UP = 7;
	uint8 public constant LEFT_DOWN = 8;
	uint8 public constant WAIT = 9;

	struct Puzzle {
			uint8[][] tiles;
			uint8 playerX;
			uint8 playerY;
			uint8 exitX;
			uint8 exitY;
	}

	struct Inventory {
			uint8 picks;
			uint8 sTiles;
			uint8 ladders;
			uint8 crystals;
	}

	struct Mods {
		uint256 mod;
		uint256 prev;
	}

	PuzzleNFT private _nft;

	// ====================================== UUPS Upgradeable ======================================

	 /// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(PuzzleNFT nft) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		_nft = nft;
	}

	function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

	// ====================================== Public Functions ======================================

	/**
	 * @dev Tests a 2x Puzzle solution. Reverts if solution impossible.
	 * @notice Builds 2x Puzzle from 4 Puzzle Ids in the following layout:
	 * <id1><id2>
	 * <id3><id4>
	 */
	function test2xSolution(uint256 puzzleId1, uint256 puzzleId2, uint256 puzzleId3, uint256 puzzleId4,
		uint8 targetCrystals, uint256[] calldata solution) external view
	{
		uint256[4] memory puzzle1 = _nft.getPuzzle(puzzleId1);
		uint256[4] memory puzzle2 = _nft.getPuzzle(puzzleId2);
		uint256[4] memory puzzle3 = _nft.getPuzzle(puzzleId3);
		uint256[4] memory puzzle4 = _nft.getPuzzle(puzzleId4);

		// Pick start and end based on puzzle 1 and 2 id numbers
		uint8 startLvlIdx = uint8(puzzleId1 % 4);
		uint8 exitLvlIdx = uint8(puzzleId2 % 4);

		Puzzle memory puzzle2x;
		puzzle2x.tiles = new uint8[][](PUZZLE_H_2X);
		for (uint i = 0; i < PUZZLE_H_2X; ++i) {
			puzzle2x.tiles[i] = new uint8[](PUZZLE_W_2X);
		}

		_populatePuzzle(puzzle2x, puzzle1, 0, PUZZLE_W, 0, PUZZLE_H, startLvlIdx == 0, exitLvlIdx == 0);
		_populatePuzzle(puzzle2x, puzzle2, PUZZLE_W, PUZZLE_W_2X, 0, PUZZLE_H, startLvlIdx == 1, exitLvlIdx == 1);
		_populatePuzzle(puzzle2x, puzzle3, 0, PUZZLE_W, PUZZLE_H, PUZZLE_H_2X, startLvlIdx == 2, exitLvlIdx == 2);
		_populatePuzzle(puzzle2x, puzzle4, PUZZLE_W, PUZZLE_W_2X, PUZZLE_H, PUZZLE_H_2X, startLvlIdx == 3, exitLvlIdx == 3);
		_testPuzzleSolution(puzzle2x, solution, targetCrystals);
	}

	/**
	 * Tests a Puzzle solution. Reverts if solution impossible.
	 */
	function testSolution(uint256 puzzleId, uint256[] calldata solution) external view {
		uint256[4] memory level = _nft.getPuzzle(puzzleId);
		Puzzle memory lvl;
		lvl.tiles = new uint8[][](PUZZLE_H);
		for (uint i; i < PUZZLE_H; ++i) {
			lvl.tiles[i] = new uint8[](PUZZLE_W);
		}

		_populatePuzzle(lvl, level, 0, PUZZLE_W, 0, PUZZLE_H, true, true);
		_testPuzzleSolution(lvl, solution, 1);
	}
	
	// ====================================== Restricted Functions ======================================

	function _testPuzzleSolution(Puzzle memory lvl, uint256[] calldata solution, uint8 targetCrystals) private pure {
		Inventory memory inv = Inventory(0, 0, 0, 0);
		_fallAndPickup(lvl, inv);

		uint8 mDir;
		uint8 mType;
		uint8 tile;
		uint8 x;
		uint8 y;

		// First 3 digits are for number of moves
		uint8 numMoves = uint8(solution[0] % 1000);
		Mods memory mods;
		mods.mod = 1000;
		mods.prev = 1000;

		uint8 j = 0;
		for (uint8 i = 0; i < numMoves; ++i) {
			// Decode move type
			mods.mod *= 10;
			mType = uint8(solution[j] % mods.mod / mods.prev);
			mods.prev = mods.mod;
			// Decode move dir
			mods.mod *= 10;
			mDir = uint8(solution[j] % mods.mod / mods.prev);
			mods.prev = mods.mod;

			// If we've reached start of uint256 in solution array, move to next
			if (mods.mod > MOD_LIMIT) {
					mods.prev = 1;
					mods.mod = 1;
					++j;
			}

			// Process move
			if (mType == MOVE) {
				if (mDir == LEFT) {
						--lvl.playerX;
				}
				else if (mDir == RIGHT) {
						++lvl.playerX;
				}
				else if (mDir == UP) {
						if (lvl.tiles[lvl.playerY][lvl.playerX] != SOFT_LADDER) {
							revert CannotMoveUp(lvl.playerX, lvl.playerY);
						}
						--lvl.playerY;
				}
				else { // mDir == DOWN
					++lvl.playerY;
				}
			}
			else if (mType == MINE) {
				// We we have picks for mining?
				if (inv.picks < 1) revert NoPicks(lvl.playerX, lvl.playerY);
				// What tile type are we mining?
				(x, y) = _playerDirToXY(lvl, mDir);
				tile = lvl.tiles[y][x];
				// Add tile to inventory
				if (tile == SOFT_BLOCK)				++inv.sTiles;
				else if (tile == SOFT_LADDER) ++inv.ladders;
				else revert										NothingToMine(x, y);
				// Remove a pick and clear mined tile
				--inv.picks;
				lvl.tiles[y][x] = NONE;
			}
			else if (mType == PLACE_BLOCK) {
				// Do we have soft blocks to palce?
				if (inv.sTiles < 1) revert NoTileToPlace(SOFT_BLOCK, x, y);
				// Is the location empty?
				(x, y) = _playerDirToXY(lvl, mDir);
				if (lvl.tiles[y][x] != NONE) revert CannotPlace(SOFT_BLOCK, x, y);
				// Place block
				--inv.sTiles;
				lvl.tiles[y][x] = SOFT_BLOCK;
			}
			else if (mType == PLACE_LADDER) {
				// Do we have ladders to place?
				if (inv.ladders < 1) revert NoTileToPlace(SOFT_LADDER, x, y);
				// Is the location empty?
				(x, y) = _playerDirToXY(lvl, mDir);				
				if (lvl.tiles[y][x] != NONE) revert CannotPlace(SOFT_LADDER, x, y);
				// Place ladder
				--inv.ladders;
				lvl.tiles[y][x] = SOFT_LADDER;
			}

			// Did we move into a solid block?
			if (_isSolid(lvl.tiles[lvl.playerY][lvl.playerX])) {
				revert MovedIntoSolid(lvl.playerX, lvl.playerY);
			}

			_fallAndPickup(lvl, inv);
		}

		// Are we at the exit and did we collect the target crystals?
		if (lvl.playerX != lvl.exitX || lvl.playerY != lvl.exitY) {
			revert NotAtExit(lvl.playerX, lvl.playerY);
		}
		if (inv.crystals < targetCrystals) {
			revert NotEnoughCrystals(inv.crystals, targetCrystals);
		}
	}

	function _isSolid(uint8 tile) private pure returns (bool) {
		return tile == SOFT_BLOCK || tile == HARD_BLOCK;
	}

	function _playerDirToXY(Puzzle memory lvl, uint8 dir) private pure returns (uint8, uint8) {
		if      (dir == RIGHT)      return (lvl.playerX + 1, lvl.playerY    );
		else if (dir == LEFT)       return (lvl.playerX - 1, lvl.playerY    );
		else if (dir == UP)         return (lvl.playerX,     lvl.playerY - 1);
		else if (dir == DOWN)       return (lvl.playerX,     lvl.playerY + 1);
		else if (dir == RIGHT_UP)   return (lvl.playerX + 1, lvl.playerY - 1);
		else if (dir == RIGHT_DOWN) return (lvl.playerX + 1, lvl.playerY + 1);
		else if (dir == LEFT_UP)    return (lvl.playerX - 1, lvl.playerY - 1);
		else         /* LEFT_DOWN */return (lvl.playerX - 1, lvl.playerY + 1);
	}
	
	function _fallAndPickup(Puzzle memory lvl, Inventory memory inv) private pure {
		uint8 lastYBlock = uint8(lvl.tiles.length - 1);
		uint8 tile = lvl.tiles[lvl.playerY][lvl.playerX];

		if (tile == SOFT_LADDER) return;
		
		// Pickup any items already touching
		if (tile == PICK) {
			++inv.picks;
			lvl.tiles[lvl.playerY][lvl.playerX] = NONE;
		}
		else if (tile == CRYSTAL) {
			++inv.crystals;
			lvl.tiles[lvl.playerY][lvl.playerX] = NONE;
		}

		// Fall and pickup items
		while (lvl.playerY < lastYBlock)
		{
			uint8 belowY = lvl.playerY + 1;
			tile = lvl.tiles[belowY][lvl.playerX];

			if (_canStandOn(tile)) return;

			if (tile == PICK)
			{
				++inv.picks;
				lvl.tiles[belowY][lvl.playerX] = NONE;
			}
			else if (tile == CRYSTAL) {
				++inv.crystals;
				lvl.tiles[belowY][lvl.playerX] = NONE;
			}

			lvl.playerY = belowY;
		}
	}
		
	function _canStandOn(uint8 tile) private pure returns (bool) {
		return tile == SOFT_BLOCK || tile == SOFT_LADDER;
	}

	/**
	 * Decode obj xy position from 3 digits
	 * The 1st digit is the quadrant with a value of 1-4,
	 * which determines if we add 10 to x and y.
	 *
	 *                x
	 *          | 0-9 |10-19
	 *    ------------------
	 *     0-9  |  1  |  2
	 *  y ------------------
	 *    10-13 |  3  |  4
	 */
	function _getNextObj(uint256[4] memory level, Mods memory mods) private pure returns (uint8 x, uint8 y) {
		// Quadrant
		mods.mod *= 10;
		uint8 quadrant = uint8(level[3] % mods.mod / mods.prev);
		mods.prev = mods.mod;
		// Y
		mods.mod *= 10;
		y = uint8(level[3] %  mods.mod / mods.prev);
		if (quadrant > 2 && y < 4) y += 10; // Ensure y not >= 14
		mods.prev = mods.mod;
		// X
		mods.mod *= 10;
		x = uint8(level[3] % mods.mod / mods.prev);
		if (quadrant % 2 == 0) x += 10;
		mods.prev = mods.mod;
	}

	function _populatePuzzle(
		Puzzle memory clevel, uint256[4] memory level,
		uint8 xStart, uint8 xEnd, uint8 yStart, uint8 yEnd,
		bool useStart, bool useExit) private pure
	{
		Mods memory mods;
		mods.mod = 1;
		mods.prev = 1;
		uint8 i = 0;
		uint8 y;
		uint8 x;
		// Decode tiles
		for (y = yStart; y < yEnd; ++y) {
			for (x = xStart; x < xEnd; ++x) {
				mods.mod *= 10;
				clevel.tiles[y][x] = uint8(level[i] % mods.mod / mods.prev);
				if (mods.mod > MOD_LIMIT) {
					mods.prev = 1;
					mods.mod = 1;
					++i;
				}
				else {
					mods.prev = mods.mod;
				}
			}
		}
		// Decode crystal xy
		(x, y) = _getNextObj(level, mods);
		clevel.tiles[y + yStart][x + xStart] = CRYSTAL;
		// Decode player xy
		if (useStart) {
			(x, y) = _getNextObj(level, mods);
			clevel.playerX = x + xStart;
			clevel.playerY = y + yStart;
		}
		else {
			mods.mod *= 10;
			mods.prev = mods.mod;
		}
		// Decode exit xy
		if (useExit) {
			(x, y) = _getNextObj(level, mods);
			clevel.exitX = x + xStart;
			clevel.exitY = y + yStart;
		}
		else {
			mods.mod *= 10;
			mods.prev = mods.mod;
		}
	}
}