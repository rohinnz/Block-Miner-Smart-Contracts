// License-Identifier: MIT
// Deployment scripts for Block Miner Game Contracts
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

  const nftContractFactory = await ethers.getContractFactory("PuzzleNFT");
  const DEFAULT_METADATA_URI = ""; // todo: Set to "ipfs://<CID>"
  const nftContract = await upgrades.deployProxy(
    nftContractFactory,
    [DEFAULT_METADATA_URI],
    { kind: "uups" }
  );
  await nftContract.deployed();
  console.log("NFT Contract deployed to: ", nftContract.address);

  // Update Unity assets
  if (network.name === "goerli" || network.name === "mainnet") {
    const exportDir = "../../unity/BlockMiner/Assets/Data/";
    updateUnitySmartContract(
      network.name,
      "PuzzleNFT",
      nftContract.address,
      exportDir
    );
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
