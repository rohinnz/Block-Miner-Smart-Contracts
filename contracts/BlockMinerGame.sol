// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Open Zeppelin Contracts
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

// Local Contracts
import "./PuzzleNFT.sol";
import "./Puzzle2xNFT.sol";

// Custom Errors
error NotNFTOwner();
error WithdrawFailed();
error MintFeeNotMet(uint256 value, uint256 mintFee);

/**
 * @title Main contract the client game will interact with.
 * @dev Contract handles Treasury, NFT Minting and Competitions.
 * 
 * @author Rohin Knight
 */
contract BlockMinerGame is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant COMPETITION_ROLE = keccak256("COMPETITION_ROLE");

	uint256 public constant PUZZLE_DATA_SIZE = 4;
	uint256 public constant PUZZLES_IN_NFT2X = 4;
	uint256 public mintFeeDev;
	uint256 public mintFeeRewards;
	uint256 public mintFeePerPuzzle;

	uint256 public nftMintFee;    // Cache for mintFeeDev + mintFeeRewards
	uint256 public bigNftMintFee; // Cache for mintFeePerPuzzle * 4

	event MintFeesUpdated();

	mapping(uint256 => uint256) private _nftRoyalties;
	mapping(address => uint256) private _bondBalances;
	mapping(address => uint256) private _lockedBondBalances;
	mapping(address => uint256) private _prizePools;  // Rewards allocated per competition contract
	uint256 public ownerBalance;
	uint256 public rewardsBalance;

	Puzzle2xNFT private _puzzle2xNFT;
	PuzzleNFT private _puzzleNFT;

	// ====================================== UUPS Upgradeable ======================================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(PuzzleNFT puzzleNFT, Puzzle2xNFT puzzle2xNFT) public initializer {
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);
		_grantRole(COMPETITION_ROLE, msg.sender);

		_puzzleNFT = puzzleNFT;
		_puzzle2xNFT = puzzle2xNFT;
	}

	function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

	// ====================================== Public Functions ======================================

	function nftWithdraw(uint256 puzzleId) external {
		if (_puzzleNFT.ownerOf(puzzleId) != msg.sender) {
			revert NotNFTOwner();
		}

		uint256 balance = _nftRoyalties[puzzleId];
		_nftRoyalties[puzzleId] = 0;

		// This call must be last to prevent a reentrancy attack.
		(bool sent, ) = msg.sender.call{value: balance}("");
		if (!sent) revert WithdrawFailed();
	}

	function nftBalance(uint256 puzzleId) external view returns (uint256) {
		return _nftRoyalties[puzzleId];
	}

	function bondBalance() external view returns (uint256) {
		return _bondBalances[msg.sender];
	}

	function lockedBondBalance() external view returns (uint256) {
		return _lockedBondBalances[msg.sender];
	}

	function depositBond() external payable {
		_bondBalances[msg.sender] += msg.value;
	}

	function withdrawBond() external {
		uint256 amount = _bondBalances[msg.sender] - _lockedBondBalances[msg.sender];
		_bondBalances[msg.sender] -= amount;

		// This call must be last to prevent a reentrancy attack.
		(bool sent, ) = msg.sender.call{value: amount}("");
		if (!sent) revert WithdrawFailed();
	}

	/**
	 * Called by game client to mint Puzzle NFT
	 */
	function safeMint(uint256[PUZZLE_DATA_SIZE] calldata data) external payable
		returns (uint256)
	{
		_depositForPuzzle();
		return _puzzleNFT.safeMint(msg.sender, data);
	}

	/**
	 * @dev Called by game client to mint Puzzle 2x NFT
	 */
	function safeMint2x(uint256[PUZZLES_IN_NFT2X] calldata puzzleIds, uint16 setupData) external payable
		returns (uint256)
	{
		_depositForPuzzle2x(puzzleIds);
		return _puzzle2xNFT.safeMint(msg.sender, puzzleIds, setupData);
	}

	// ==================================== Restricted Functions ====================================

	function ownerWithdraw(address to) external onlyRole(UPGRADER_ROLE) {
		ownerBalance = 0;
		(bool sent, ) = to.call{value: ownerBalance}("");
		if (!sent) revert WithdrawFailed();
	}

	function setMintFees(uint256 devFee, uint256 rewardsFee, uint256 perPuzzleFee) external onlyRole(UPGRADER_ROLE) {
		mintFeeDev = devFee;
		mintFeeRewards = rewardsFee;
		mintFeePerPuzzle = perPuzzleFee;

		// Calculate NFT mint fees
		unchecked {
			nftMintFee = mintFeeDev + mintFeeRewards;
			bigNftMintFee = mintFeePerPuzzle * PUZZLES_IN_NFT2X;
		}

		emit MintFeesUpdated();
	}

	function lockBond(uint256 amount) public onlyRole(COMPETITION_ROLE) {
		_lockedBondBalances[msg.sender] += amount;
		assert(_lockedBondBalances[msg.sender] <= _bondBalances[msg.sender]);
	}

	function unlockBond(uint256 amount) public onlyRole(COMPETITION_ROLE) {
		_lockedBondBalances[msg.sender] -= amount; // Will throw exception if underflow attempted
	}

	function payBondTo(address bondOwner, address recipient, uint256 amount) public onlyRole(COMPETITION_ROLE) {
		_lockedBondBalances[bondOwner] -= amount;  // Will throw exception if underflow attempted
		_bondBalances[bondOwner] -= amount;

		(bool sent, ) = recipient.call{value: amount}("");
		if (!sent) revert WithdrawFailed();
	}

	// ===================================== Internal Functions =====================================

	function _depositForPuzzle() private {
		if (msg.value != nftMintFee) {
			revert MintFeeNotMet(msg.value, nftMintFee);
		}
		unchecked {
			ownerBalance += mintFeeDev;
			rewardsBalance += mintFeeRewards;
		}
	}

	function _depositForPuzzle2x(uint256[PUZZLES_IN_NFT2X] calldata puzzleIds) private {
		if (msg.value != bigNftMintFee) {
			revert MintFeeNotMet(msg.value, bigNftMintFee);
		}
		unchecked {
			_nftRoyalties[puzzleIds[0]] += mintFeePerPuzzle;
			_nftRoyalties[puzzleIds[1]] += mintFeePerPuzzle;
			_nftRoyalties[puzzleIds[2]] += mintFeePerPuzzle;
			_nftRoyalties[puzzleIds[3]] += mintFeePerPuzzle;
		}
	}
}
