// License-Identifier: MIT
// Deployment scripts for Block Miner Game Contracts
import { BaseContract } from "ethers";
import { ethers, network, upgrades } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { updateUnitySmartContract } from "./unity";

/**
 * Deploy contracts and update ABIs references in Unity
 *
 * Networks: localhost, goerli, mainnet
 * Deploy command: npx hardhat run scripts/deploy.ts --network <network name>
 *
 * @author Rohin Knight
 */
async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account: ", deployer.address);
  console.log("Account balance: ", (await deployer.getBalance()).toString());

  // Deploy Contracts
  const DEFAULT_METADATA_URI = ""; // todo: Set to "ipfs://<CID>"
  const DEFAULT_METADATA_URI_2X = ""; // todo: Set to "ipfs://<CID>"
  const COMPETITION_BOND = ethers.utils.parseEther("0.01");

  const puzzleNFTContract = await deployUpgradableContract("PuzzleNFT", [
    DEFAULT_METADATA_URI,
  ]);

  const puzzle2xNFTContract = await deployUpgradableContract("Puzzle2xNFT", [
    DEFAULT_METADATA_URI_2X,
    puzzleNFTContract.address,
  ]);

  const solutionCheckerContract = await deployUpgradableContract(
    "SolutionChecker",
    [puzzleNFTContract.address]
  );

  const blockMinerGameContract = await deployUpgradableContract(
    "BlockMinerGame",
    [puzzleNFTContract.address, puzzle2xNFTContract.address]
  );

  await deployUpgradableContract("ManualCompetition2x", [
    blockMinerGameContract.address,
    solutionCheckerContract.address,
    COMPETITION_BOND,
  ]);

  // Update Unity assets
  if (network.name === "goerli" || network.name === "mainnet") {
    const exportDir = "../../unity/BlockMiner/Assets/Data/";
    updateUnitySmartContract(
      network.name,
      "PuzzleNFT",
      puzzleNFTContract.address,
      exportDir
    );
  }
}

async function deployUpgradableContract(
  contractName: string,
  args: unknown[] = []
): Promise<BaseContract> {
  const factory = await ethers.getContractFactory(contractName);
  const contract = await upgrades.deployProxy(factory, args, { kind: "uups" });
  await contract.deployed();
  console.log(
    "%s Contract deployed to %s with args %s",
    contractName,
    contract.address,
    args
  );
  return contract;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
