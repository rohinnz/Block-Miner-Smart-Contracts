// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Local Contracts
import "./APuzzleNFT.sol";

/**
 * @title Upgradeable ERC721 contract for 20x14 tile puzzles
 * 
 * @author Rohin Knight
 */
contract PuzzleNFT is APuzzleNFT {
	using CountersUpgradeable for CountersUpgradeable.Counter;
	// Number of uint256 numbers packed into each puzzle
	uint8 public constant DATA_SIZE = 4;
	// Mapping ID to puzzle data
	mapping(uint256 => uint256[DATA_SIZE]) private _idsToData;

	// ====================================== UUPS Upgradeable ======================================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
			_disableInitializers();
	}

	function initialize(string calldata defaultURI) public initializer {
		__ERC721_init("Block Miner Puzzle", "BMP");
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(MINTER_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);

		_defaultURI = defaultURI;
	}

	function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}
	
	// ====================================== Public Functions ======================================

	/**
	 * @return Token ID for puzzle data. 0 means no puzzle exists.
	 */
	function getPuzzleId(uint256[DATA_SIZE] calldata data) public view returns (uint256) {
		bytes32 puzzleHash = keccak256(abi.encodePacked(data));
		return _hashesToIds[puzzleHash];
	}

	/**
	 * @return Puzzle for the given ID.
	 */
	function getPuzzle(uint256 id) public view returns (uint256[DATA_SIZE] memory) {
		return _idsToData[id];
	}

	/**
	 * @dev Array of puzzles for the given IDs.
	 */
	function getPuzzles(uint256[] calldata ids) public view returns (uint256[DATA_SIZE][] memory nfts) {
		nfts = new uint256[DATA_SIZE][](ids.length);
		for (uint i = 0; i < ids.length; ++i) {
			nfts[i] = _idsToData[ids[i]];
		}
	}

	// ==================================== Restricted Functions ====================================

	/**
	 * @dev Mints a Puzzle NFT. Should only be called from authorized contract
	 * todo: Write test for reentrancy attack on this function
	 */
	function safeMint(address to, uint256[DATA_SIZE] calldata data) public
		onlyRole(MINTER_ROLE)
		returns (uint256)
	{
		// Get data hash and revert if puzzle already minted
		bytes32 puzzleHash = keccak256(abi.encodePacked(data));
		if (_hashesToIds[puzzleHash] != 0) revert AlreadyMinted();

		// Get new token id. We increment first so 0 can mean invalid/no token
		_tokenIds.increment();
		uint256 id = _tokenIds.current();

		// Store data and data hash
		_hashesToIds[puzzleHash] = id;
		_idsToData[id] = data;
		
		// Mint and emit event
		_safeMint(to, id);
		emit NewPuzzle(id);
		return id;
	}
}
