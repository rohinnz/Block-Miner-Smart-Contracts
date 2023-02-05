// SPDX-License-Identifier: MIT
// Block Miner Game Contracts
pragma solidity 0.8.17;

// Open Zeppelin Contracts
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Local Contracts
import "./BlockMinerGame.sol";
import "./SolutionChecker.sol";

// Custom Errors
error BondNotEnough();
error SolutionNotEqualHash();
error CompetitionAlreadyFinished();
error OutsideTestTimeWindow();

error SolutionIsValid();
error NoSolutionOwner();
error HashAlreadySet();

error CompetitionStillRunning();
error UnclaimedPrize(address recipient);
//error PrizeAlreadyAwarded();

/**
 * @title Competition to solve a 2x puzzle which is set manually by contract owner.
 * 
 * @author Rohin Knight
 */
contract ManualCompetition2x is Initializable, OwnableUpgradeable, UUPSUpgradeable {
	struct Competition {
		uint256[4] puzzleIds;
		uint16 setupData;
		uint256 startTimestamp;
	}

	struct Solution {
		bytes32 hash;
		uint256[] moves;
		address owner;
	}

	Competition public currentComp;
	Solution public currentSolution;

	uint256 public requiredBond;
	uint256 public compDur = 1 hours;
	uint256 public testDur = 15 minutes;

	BlockMinerGame private _blockMinerGame;
	SolutionChecker private _solutionChecker;

	// ====================================== UUPS Upgradeable ======================================

	 /// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(BlockMinerGame game, SolutionChecker solutionChecker, uint256 bond) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		_blockMinerGame = game;
		_solutionChecker = solutionChecker;
		requiredBond = bond;
	}

	function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

	// ====================================== Public Functions ======================================

	/**
	 * @dev Player required to submit hash to solution first. This is to prevent
	 * another player from stealing their solution by front-running the transaction.
	 */
	function submitSolutionHash(bytes32 hash) external {
		if (block.timestamp > currentComp.startTimestamp + compDur) {
			revert CompetitionAlreadyFinished();
		}
		if (_blockMinerGame.availableBond() < requiredBond) {
			revert BondNotEnough();
		}
		if (currentSolution.owner != address(0)) {
			revert HashAlreadySet();
		}

		_blockMinerGame.lockBond(msg.sender, requiredBond);
		currentSolution.owner = msg.sender;
		currentSolution.hash = hash;
	}

	/**
	 * @dev Submit the solution. Requires the solution hash to already be set.
	 */
	function submitSolution(uint256[] calldata moves) external {
		if (block.timestamp > currentComp.startTimestamp + compDur) {
			revert CompetitionAlreadyFinished();
		}
		if (currentSolution.hash != keccak256(abi.encodePacked(moves))) {
			revert SolutionNotEqualHash();
		}

		currentSolution.moves = moves;
	}

	/**
	 * @dev If a player has submitted an invalid solution, another player can take their bond
	 */
	function takePlayerBond() external {
		if (block.timestamp < currentComp.startTimestamp + compDur ||
				block.timestamp > currentComp.startTimestamp + compDur + testDur) {
			revert OutsideTestTimeWindow();
		}
		if (currentSolution.owner == address(0)) {
			revert NoSolutionOwner();
		}
		if (_solutionChecker.test2xSolutionBool(currentComp.puzzleIds, currentComp.setupData, currentSolution.moves)) {
			revert SolutionIsValid();
		}

		address bondOwner = currentSolution.owner;
		currentSolution.owner = address(0);
		_blockMinerGame.payBondTo(msg.sender, bondOwner, requiredBond); // Call this function last to prevent reentrancy attack
	}

	/**
	 * @dev Unlocks the bond of the solution's address and awards the prize.
	 */
	function unlockBondAwardPrize() external {
		if (block.timestamp < currentComp.startTimestamp + compDur + testDur) {
			revert CompetitionStillRunning();
		}
		if (currentSolution.owner == address(0)) {
			revert NoSolutionOwner();
		}
		
		address owner = currentSolution.owner;
		currentSolution.owner = address(0);

		_blockMinerGame.unlockBond(owner, requiredBond);
		_blockMinerGame.rewardPrizeTo(owner); // Call this function last to prevent reentrancy attack
	}

	// ====================================== Restricted Functions ======================================

	function setRequiredBond(uint256 bond) external onlyOwner {
		if (block.timestamp < currentComp.startTimestamp + compDur + testDur) {
			revert CompetitionStillRunning();
		}
		if (currentSolution.owner != address(0)) {
			revert UnclaimedPrize(currentSolution.owner);
		}

		requiredBond = bond;
	}

	function setDurations(uint256 comp, uint256 test) external onlyOwner {
		if (block.timestamp < currentComp.startTimestamp + compDur + testDur) {
			revert CompetitionStillRunning();
		}
		compDur = comp;
		testDur = test;
	}

	function startCompetition(uint256[4] calldata puzzleIds, uint16 setupData, uint256 prizeAmount) external onlyOwner {
		if (block.timestamp < currentComp.startTimestamp + compDur + testDur) {
			revert CompetitionStillRunning();
		}
		if (currentSolution.owner != address(0)) {
			revert UnclaimedPrize(currentSolution.owner);
		}

		_blockMinerGame.allocatePrize(prizeAmount);
		currentSolution.owner = address(0);
		currentComp = Competition(puzzleIds, setupData, block.timestamp);
	}
}
