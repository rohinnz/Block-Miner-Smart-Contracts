// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Local Contracts
import "./APuzzleNFT.sol";
import "./PuzzleNFT.sol";

/**
 * Revert error used when attempting to mint with existing puzzle data
 */
error InvalidPuzzleId(uint256 id);

/**
 * @title Upgradeable ERC721 contract for 40x28 tile puzzles, made from 4 20x14 tile puzzles
 * 
 * @author Rohin Knight
 */
contract Puzzle2xNFT is APuzzleNFT {
	using CountersUpgradeable for CountersUpgradeable.Counter;
	// Number of puzzles in a 2x puzzle
	uint8 public constant NUM_PUZZLES = 4;
	// Struct to store puzzle ids and setup info (Start pos, end pos, crystal target)
	struct PackedPuzzle {
		uint256[NUM_PUZZLES] puzzleIds;
		uint16 setup;
	}
	// Mapping token id to level
	mapping(uint256 => PackedPuzzle) private _idsToData;

	PuzzleNFT _puzzleNFT;

	// ====================================== UUPS Upgradeable ======================================
	
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(string calldata defaultURI, PuzzleNFT puzzleNFT) public initializer {
		__ERC721_init("Block Miner Puzzle 2x", "BMP2x");
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(MINTER_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);

		_defaultURI = defaultURI;
		_puzzleNFT = puzzleNFT;
	}
	
	function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

	// ====================================== Public Functions ======================================

	/**
	 * @dev Returns array of 4 puzzle ids and uint16 with setup info
	 */
	function getPuzzle(uint256 id2x) public view returns (uint256[NUM_PUZZLES] memory puzzleIds, uint16 setup) {
		PackedPuzzle memory p = _idsToData[id2x];
		puzzleIds = p.puzzleIds;
		setup = p.setup;
	}

	/**
	 * @dev Returns multi-dimensional array of 4 puzzle ids for each 2x puzzle
	 * and a second array with setup info
	 */
	function getPuzzles(uint256[] calldata ids2x) public view
		returns (uint256[NUM_PUZZLES][] memory puzzleIds, uint16[] memory setups)
	{
		puzzleIds = new uint256[NUM_PUZZLES][](ids2x.length);
		setups = new uint16[](ids2x.length);

		for (uint i = 0; i < ids2x.length; ++i) {
			PackedPuzzle memory p = _idsToData[ids2x[i]];
			puzzleIds[i] = p.puzzleIds;
			setups[i] = p.setup;
		}
	}

	// ==================================== Restricted Functions ====================================

	/**
	 * @dev Mints a Puzzle 2x NFT. Should only be called from authorized contract
	 * todo: Write test for reentrancy attack on this function
	 */
	function safeMint(address to, uint256[NUM_PUZZLES] calldata puzzleIds, uint16 setup) public onlyRole(MINTER_ROLE) {
		// Get data hash and revert if puzzle already minted
		bytes32 puzzleHash = keccak256(abi.encodePacked(puzzleIds));
		if (_hashesToIds[puzzleHash] != 0) revert AlreadyMinted();

		uint256 totalPuzzles = _puzzleNFT.totalMinted();
		_checkPuzzleId(puzzleIds[0], totalPuzzles);
		_checkPuzzleId(puzzleIds[1], totalPuzzles);
		_checkPuzzleId(puzzleIds[2], totalPuzzles);
		_checkPuzzleId(puzzleIds[3], totalPuzzles);

		// Get new token id. We increment first so 0 can mean invalid/no token
		_tokenIds.increment();
		uint256 id2x = _tokenIds.current();

		// Store data and data hash
		_idsToData[id2x] = PackedPuzzle(puzzleIds, setup);
		_hashesToIds[puzzleHash] = id2x;
		
		// Mint and emit event
		_safeMint(to, id2x);
		emit NewPuzzle(id2x);
	}

	// This function is a great candidate for inlining.
	// todo later: Check if inlining has been added.
	// Current feature request https://github.com/ethereum/solidity/issues/13248
	function _checkPuzzleId(uint256 id, uint256 totalPuzzles) private pure {
		if (id < 1 || id > totalPuzzles) revert InvalidPuzzleId(id);
	}
}
