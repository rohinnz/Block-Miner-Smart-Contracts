// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Open Zeppelin Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Local Contracts
import "./PuzzleNFT.sol";
import "./Puzzle2xNFT.sol";

// todo: Make UUPS Upgradeable
error NotNFTOwner();
error WithdrawFailed(uint256 amount);
error MintFeeNotMet(uint256 value, uint256 mintFee);

/**
 * @title  Abstract base class for puzzle minter contract
 * 
 * @author Rohin Knight
 */
contract BlockMinerGame is Initializable, OwnableUpgradeable, UUPSUpgradeable {
	uint256 public constant PUZZLE_DATA_SIZE = 4;
	uint256 public constant PUZZLES_IN_NFT2x = 4;
	uint256 public mintFeeDev;
	uint256 public mintFeeRewards;
	uint256 public mintFeePerPuzzle;

	event MintFeesUpdated();

	mapping(uint256 => uint256) internal _nftBalances;
	mapping(address => uint256) internal _bondBalances;
	uint256 public ownerBalance;
	uint256 public rewardsBalance;

	Puzzle2xNFT internal _puzzle2xNFT;
	PuzzleNFT internal _puzzleNFT;

	// ====================================== UUPS Upgradeable ======================================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(PuzzleNFT puzzleNFT, Puzzle2xNFT puzzle2xNFT) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		_puzzleNFT = puzzleNFT;
		_puzzle2xNFT = puzzle2xNFT;
	}

	function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

	// ====================================== Public Functions ======================================

	function nftWithdraw(uint256 puzzleId) external {
		if (_puzzleNFT.ownerOf(puzzleId) != msg.sender) {
			revert NotNFTOwner();
		}

		uint256 balance = _nftBalances[puzzleId];
		_nftBalances[puzzleId] = 0;

		// WARNING: The msg.sender.call must be last to prevent a reentrancy attack. 
		// If another update line must come after then we must use a reentrancy
		// guard modifier which will cost more gas.
		//
		// todo: Write test with reentrancy attack contract
		(bool sent, ) = msg.sender.call{value: balance}("");
		if (!sent) revert WithdrawFailed(balance);
	}

	function nftBalance(uint256 puzzleId) external view returns (uint256) {
		return _nftBalances[puzzleId];
	}

	function bondBalance() external view returns (uint256) {
		return _bondBalances[msg.sender];
	}

	function depositBond() external payable {
		_bondBalances[msg.sender] += msg.value;
	}

	function withdrawBond() external {
		// todo: Check if account's bond is currently locked

		uint256 balance = _bondBalances[msg.sender];
		_bondBalances[msg.sender] = 0;

		// WARNING: The msg.sender.call must be last to prevent a reentrancy attack. 
		// If another update line must come after then we must use a reentrancy
		// guard modifier which will cost more gas.
		//
		// todo: Write test with reentrancy attack contract
		(bool sent, ) = msg.sender.call{value: balance}("");
		if (!sent) revert WithdrawFailed(balance);
	}

	// Fee to mint NFT puzzle
	function nftMintFee() public view returns (uint256) {
		return mintFeeDev + mintFeeRewards;
	}

	// Fee to mint Big NFT puzzle
	function bigNftMintFee() public view returns (uint256) {
		return mintFeePerPuzzle * PUZZLES_IN_NFT2x;
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
	function safeMint2x(uint256[PUZZLES_IN_NFT2x] calldata puzzleIds, uint16 setupData) external payable
		returns (uint256)
	{
		_depositForPuzzle2x(puzzleIds);
		return _puzzle2xNFT.safeMint(msg.sender, puzzleIds, setupData);
	}

	// ==================================== Restricted Functions ====================================

	function ownerWithdraw(address to) external onlyOwner {
		(bool sent, ) = to.call{value: ownerBalance}("");
		if (!sent) revert WithdrawFailed(ownerBalance);
		ownerBalance = 0;
	}

	function setMintFees(uint256 devFee, uint256 rewardsFee, uint256 perPuzzleFee) external onlyOwner {
		mintFeeDev = devFee;
		mintFeeRewards = rewardsFee;
		mintFeePerPuzzle = perPuzzleFee;

		emit MintFeesUpdated();
	}

	// ===================================== Internal Functions =====================================

	function _depositForPuzzle() internal {
		if (msg.value != nftMintFee()) {
			revert MintFeeNotMet(msg.value, nftMintFee());
		}
		ownerBalance += mintFeeDev;
		rewardsBalance += mintFeeRewards;
	}

	function _depositForPuzzle2x(uint256[PUZZLES_IN_NFT2x] calldata puzzleIds) internal {
		if (msg.value != bigNftMintFee()) {
			revert MintFeeNotMet(msg.value, bigNftMintFee());
		}
		_nftBalances[puzzleIds[0]] += mintFeePerPuzzle;
		_nftBalances[puzzleIds[1]] += mintFeePerPuzzle;
		_nftBalances[puzzleIds[2]] += mintFeePerPuzzle;
		_nftBalances[puzzleIds[3]] += mintFeePerPuzzle;
	}
}
