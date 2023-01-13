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
 * @title Abstract base class for all puzzle NFTs
 * 
 * @author Rohin Knight
 */
abstract contract APuzzleNFT is Initializable, ERC721Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	// Token counter for assigning id
	using CountersUpgradeable for CountersUpgradeable.Counter;
	CountersUpgradeable.Counter internal _tokenIds;

	/** 
	 * @dev Event called when new puzzle created
	 */
	event NewPuzzle(uint256 id);
	// Mapping puzzle hash to ID
	mapping(bytes32 => uint256) internal _hashesToIds;
	// Mapping ID to CID
	mapping(uint256 => string) internal _idsToCIDs;
	// Default URI used when CID not set for ID
	string internal _defaultURI;

	/**
	 * @dev Last ID with a CID set. ID is greater then we know the CID has not yet been set.
	 */
	uint256 public lastIdWithCID;

	// ====================================== Public Functions ======================================

	/**
	 * @return Total number of minted NFTs
	 */
	function totalMinted() public view returns (uint256) {
		return _tokenIds.current();
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
	function supportsInterface(bytes4 interfaceId) public view
		override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	// ==================================== Restricted Functions ====================================
	
	/** 
	 * @dev Protocol is IPFS
	 */
	function _baseURI() internal pure override returns (string memory) {
		return "ipfs://";
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
