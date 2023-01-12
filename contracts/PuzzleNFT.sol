// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Open Zeppelin Contracts
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * Revert error used when attempting to mint with existing puzzle data
 */
error AlreadyMinted();

/**
 * @title Upgradeable ERC721 contract for 20x14 tile puzzles
 * 
 * @author Rohin Knight
 */
contract PuzzleNFT is Initializable, ERC721Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
	uint8 public constant DATA_SIZE = 4;
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	// Token counter for assigning id
	using CountersUpgradeable for CountersUpgradeable.Counter;
	CountersUpgradeable.Counter private _tokenIds;
	/** 
	 * @dev Event called when new puzzle created
	 */
	event NewPuzzle(uint256 id);
	// Mapping ID to puzzle data
	mapping(uint256 => uint256[DATA_SIZE]) private _idsToData;
	// Mapping puzzle hash to ID
	mapping(bytes32 => uint256) private _hashesToIds;
	// Mapping ID to CID
	mapping(uint256 => string) private _idsToCIDs;
	// Default URI used when CID not set for ID
	string private _defaultURI;

	/**
	 * @dev Last ID with a CID set. ID is greater then we know the CID has not yet been set.
	 */
	uint256 public lastIdWithCID;

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
	 * @return Total number of minted NFTs
	 */
	function totalMinted() public view returns (uint256) {
		return _tokenIds.current();
	}

	/**
	 * @return Puzzle for the given ID.
	 */
	function getPuzzle(uint256 id) public view returns (uint256[DATA_SIZE] memory) {
		return _idsToData[id];
	}

	/**
	 * @return Array of puzzles for the given IDs.
	 */
	function getPuzzles(uint256[] calldata ids) public view returns (uint256[DATA_SIZE][] memory) {
		uint256[DATA_SIZE][] memory nfts = new uint256[DATA_SIZE][](ids.length);
		for (uint i = 0; i < ids.length; ++i) {
			nfts[i] = _idsToData[ids[i]];
		}
		return nfts;
	}

	/**
	 * @return specific URI for ID, or default URI if CID not set.
	 */
	function tokenURI(uint256 id) public view virtual override returns (string memory) {
		_requireMinted(id);
		string memory cid = _idsToCIDs[id];

		// todo: find out if there is a performance difference between string.concat and abi.encodePacked
		// probably doesn't matter that much as this function is unlikely to get called in a transaction.
		return bytes(cid).length != 0 ? string.concat(_baseURI(), cid) : _defaultURI;
	}

	// Override required by Solidity
	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(ERC721Upgradeable, AccessControlUpgradeable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	// ====================================== Restricted Functions ======================================

	/** 
	 * @dev Protocol is IPFS
	 */
	function _baseURI() internal pure override returns (string memory) {
		return "ipfs://";
	}

	/**
	 * @dev Mints a Puzzle NFT. Should only be called from authorized contract
	 * todo: Write test for reentrancy attack on this function
	 */
	function safeMint(address to, uint256[DATA_SIZE] calldata data) public onlyRole(MINTER_ROLE) returns (uint256) {
		// Get data hash and revert if puzzle already minted
		bytes32 puzzleHash = keccak256(abi.encodePacked(data));
		if (_hashesToIds[puzzleHash] != 0) {
			revert AlreadyMinted();
		}

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

	/**
	 * @dev Sets default URI that will be returned if CID not set for ID
	 */
	function setDefaultURI(string calldata defaultURI) external onlyRole(UPGRADER_ROLE) {
		_defaultURI = defaultURI;
	}

	/**
	 * @dev Set CIDs, starting after the last ID set. CIDs should only be set once.
	 */
	function setCIDs(string[] calldata cids) external onlyRole(UPGRADER_ROLE) {
		for (uint i = 0; i < cids.length; ++i) {
			unchecked {
				++lastIdWithCID;
			}
			_idsToCIDs[lastIdWithCID] = cids[i];
		}
	}

	/**
	 * @dev Fix CID for token. Should only be used if there is an issue with an assigned CID.
	 */
	function fixCID(uint256 id, string calldata cid) external onlyRole(UPGRADER_ROLE) {
		_idsToCIDs[id] = cid;
	}
}
