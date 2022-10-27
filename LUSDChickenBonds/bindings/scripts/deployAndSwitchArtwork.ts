// Usage:
// yarn -s ts-node scripts/deployAndSwitchArtwork.ts --addresses-file ../addresses/mainnet.json --set-artwork --verify
//
// Options
// --addresses-file: File to get current deployment from, and to add newly deployed addresses to
// --set-artwork: To set the new final artwork address into BondNFT contract
// --not-check: To skip final NFT generation and checks. Incompatible with --set-artwork
// --verify: To verify contracts on Etherscan (TODO)
//
// Make sure you have run previously:
// forge build (in the parent folder)
// yarn prepare
//
// Optional: You can convert SVG files to PNG with:
// for i in $(ls tmp/artwork-mainnet-deployment/svg/); do convert tmp/artwork-mainnet-deployment/svg/$i tmp/artwork-mainnet-deployment/png/$i.png; done;


import assert from "assert";
import fs from "fs-extra";
import path from "path";
import * as readline from "readline";
import chalk from 'chalk';
import decamelize from 'decamelize';
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import axios from "axios";

import { getContractFactories, mapArtworkContracts } from "../src/contracts";
import { getBondNFT, deployNFTArtworkUpgrade, LUSDChickenBondArtworkDeployedContracts, DeployedContract } from "../src/deployment";
import { writeNFT, checkMetadata } from "../src/NFTHelpers";
import { BondNFT, BondNFTArtworkSwitcherTester } from "../src/generated/types";

const REAL_MAINNET_BOND_NFT_ADDRESS = "0xa8384862219188a8f03c144953Cf21fc124029Ee";

// Addresses input/output file
let addressesFile = "../addresses/mainnet-dry-run.json";
if (process.argv.includes("--addresses-file")) {
  const addressesIndex = process.argv.indexOf("--addresses-file");
  assert(process.argv.length > addressesIndex + 1);
  addressesFile = process.argv[addressesIndex + 1]
}

// Command line options
const isSetArtwork = process.argv.includes("--set-artwork");
const isVerify = process.argv.includes("--verify");
const isNotCheck = process.argv.includes("--not-check");

const deploymentAddresses = JSON.parse(fs.readFileSync(addressesFile, "utf-8"))

const numEggs = 10;
const outDir = path.join("tmp", "artwork-mainnet-deployment");
const svgDir = path.join(outDir, "svg");
const jsonDir = path.join(outDir, "json");
const pngDir = path.join(outDir, "png");

fs.removeSync(outDir);
fs.mkdirSync(svgDir, { recursive: true });
fs.mkdirSync(jsonDir, { recursive: true });
fs.mkdirSync(pngDir, { recursive: true });

const defaultRpcUrl = "http://127.0.0.1:8545";

const deployerPrivateKeyChain = [
  // The only initial account on OpenEthereum's dev chain
  "0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7",
  // Account #1 on Hardhat/Anvil
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
];

const getProvider = () => {
  const envRpcUrl = process.env.RPC_URL ?? "";

  if (envRpcUrl.length > 0) {
    console.log("Connecting through configured RPC_URL ...");
    return new JsonRpcProvider(envRpcUrl);
  } else {
    console.log(`Connecting through ${defaultRpcUrl} ...`);
    return new JsonRpcProvider(defaultRpcUrl);
  }
};

const getDeployerFromKeychain = async (provider: JsonRpcProvider) => {
  const deployers = await Promise.all(
    deployerPrivateKeyChain
      .map(deployerPrivateKey => new Wallet(deployerPrivateKey, provider))
      .map((wallet, i) => wallet.getBalance().then(balance => ({ balance, wallet, i })))
  );

  const deployer = deployers.find(({ balance }) => !balance.isZero());

  if (!deployer) {
    throw new Error("neither private key holds any Ether");
  }

  console.log(`Using key #${deployer.i + 1} from keychain ...`);

  return deployer.wallet;
};

const getDeployer = () => {
  const provider = getProvider();
  const envDeployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? "";

  if (envDeployerPrivateKey.length > 0) {
    console.log("Using configured DEPLOYER_PRIVATE_KEY ...");
    return new Wallet(envDeployerPrivateKey, provider);
  } else {
    return getDeployerFromKeychain(provider);
  }
};

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const proceedYN = async (question: string) => {
  return new Promise((resolve) => {
    let result = false;  rl.question(question + " (y/n) ", (answer) => {
      switch(answer.toLowerCase()) {
        case "y":
          result = true;
          break;
        default:
          result = false;
          break;
      }
      resolve(result);
    });
  });
};

const initialChecks = async (deployerAddress: string, bondNFT: BondNFT) => {
  console.log(`Deployer address: ${deployerAddress}`);
  if (isSetArtwork) {
    if (isNotCheck) {
      console.error("Check is mandatory when setting new artwork, remove --not-check or --set-artwork options");
      process.exit(1);
    }
    const bondNFTOwner = await bondNFT.owner();
    const isBondNFTOwner = deployerAddress === bondNFTOwner;
    if (!isBondNFTOwner) {
      console.log();
      console.log("bondNFTOwner: ", bondNFTOwner);
      console.log("deployer:     ", deployerAddress);
      console.error("Deployer is not BondNFT owner. You’ll be able to deploy, but not to switch Artwork")
      console.error("Remove --set-artwork option if you want to deploy anyway.")
      process.exit(1);
    }
    console.log(chalk.yellow("New artwork address will be set in BondNFT contract!"));
  } else {
    console.log(chalk.yellow("New artwork address will *not* be set in BondNFT contract!"));
  }
  if (isVerify) {
    if (!process.env.ETHERSCAN_API_KEY) {
      console.error("No etherscan key available, remove --verify option");
      process.exit(1);
    }
    console.log(chalk.grey("Contracts will be verified"));
  } else {
    console.log(chalk.grey("Contracts will *not* be verified"));
  }
  if (!await proceedYN("Do you want to continue?")) {
    process.exit(1);
  }

  console.log();
};

const verifyContract = async (contractName: string, contractAddress: string/*, sourceCode: string*/, constructorArguments=[]) => {
  const url = "https://api.etherscan.io/api";
  const sourceCode = fs.readFileSync(`artifacts/${contractName}.flat.sol`, "utf-8");
  try {
    const response = await axios.post(
      url,
      {
        apikey: process.env.ETHERSCAN_API_KEY,
        module: "contract",
        action: "verifysourcecode",
        sourceCode: sourceCode,
        contractaddress: contractAddress,
        codeformat: "solidity-single-file",
        contractname: contractName,
        compilerversion: "0.8.15",
        optimizationUsed: 1,
        runs: 500,
        constructorArguements: constructorArguments,
        licenseType: 5 // GPL-v3
      },
      {
        headers: {'content-type': 'application/x-www-form-urlencoded'}
      }
    );
    //console.log('response: ', response);
  } catch (exception) {
    process.stderr.write(`ERROR received from ${url}: ${exception}\n`);
  }
};

const verifyContracts = async(deployment: LUSDChickenBondArtworkDeployedContracts) => {
  console.log("Skipping verification. Must be done manually");
  // TODO:
  /*
  await Promise.all(
    Object.entries(deployment).map(
      ([, deployedContract]) => [
        verifyContract(deployedContract.contractName, deployedContract.contract.address, [])
      ]
    )
  );
  */
}

const generateAndCheckFinalNFTs = async (bondNFT: BondNFT, bondNFTArtworkSwitcherTester: BondNFTArtworkSwitcherTester, numEggs: number) => {
  for (let i = 1; i <= numEggs; ++i) {
    //console.log(`Egg ${i}`);

    const totalSupply = await bondNFT.totalSupply();
    const bondID = 1 + Math.floor(totalSupply.toNumber() * Math.random());
    console.log("bondID: ", bondID);

    const eggTokenURI = await bondNFT.tokenURI(bondID);
    const eggMetadata = await writeNFT(bondID, eggTokenURI, jsonDir, svgDir, "1-egg");
    //console.log('eggMetadata: ', eggMetadata);

    const chickenOutTokenURI = await bondNFTArtworkSwitcherTester.tokenURITester(bondID, 2);
    const chickenOutMetadata = await writeNFT(bondID, chickenOutTokenURI, jsonDir, svgDir, "2-chicken-out");
    //console.log('chickenOutMetadata: ', chickenOutMetadata)

    const chickenInTokenURI = await bondNFTArtworkSwitcherTester.tokenURITester(bondID, 3);
    const chickenInMetadata = await writeNFT(bondID, chickenInTokenURI, jsonDir, svgDir, "2-chicken-in");

    checkMetadata(eggMetadata, chickenOutMetadata);
    checkMetadata(eggMetadata, chickenInMetadata);
  }
};

const setNewArtworkAddress = async (deployment: LUSDChickenBondArtworkDeployedContracts, bondNFT: BondNFT) => {
    const newArtworkAddress = deployment.bondNFTArtworkSwitcher.contract.address;

    console.log("")
    console.log("  --- WARNING ---");
    console.log("  Make sure everything is correct before continuing!");
    console.log("")
    console.log("  --> The BondNFT contract that will be modified is: " + chalk.red(bondNFT.address));
    console.log("  https://etherscan.io/address/" + bondNFT.address);
    console.log("")
    if (bondNFT.address === REAL_MAINNET_BOND_NFT_ADDRESS) {
      console.log(chalk.red(" ** You are modifying real mainnet BondNFT contract! **"))
      console.log("")
    }
    console.log("  The new artwork address will be: " + chalk.cyan(newArtworkAddress));
    console.log("  https://etherscan.io/address/" + newArtworkAddress);
    console.log("")
    console.log("  Go to " + chalk.green(svgDir) + " folder and check that NFT transitions look good");
    console.log("  and are consistent with current NFTs, which you can browse here:");
    console.log("  https://looksrare.org/collections/0xa8384862219188a8f03c144953Cf21fc124029Ee");
    console.log("  ---------------");
    console.log("")

    if (await proceedYN("Are you sure you want to continue?")) {
      await bondNFT.setArtworkAddress(newArtworkAddress);
      console.log();
      console.log("Set Artwork address succeeded!");
    }
};

const logMDReport = (deployment: LUSDChickenBondArtworkDeployedContracts) => {
  console.log();
  console.log("---");
  console.log("## Deployment transactions");
  console.log();
  mapArtworkContracts<DeployedContract, string>(deployment, deployedContract => {
    const etherscanLink = `https://etherscan.io/tx/${deployedContract.receipt.transactionHash}`;
    console.log(`[${deployedContract.contractName}](${etherscanLink})`);
    console.log();
    return etherscanLink;
  });
  console.log("---");
};

const writeDeployment = (deployment: LUSDChickenBondArtworkDeployedContracts) => {
  //console.log('deploymentAddresses: ', deploymentAddresses)
  mapArtworkContracts<DeployedContract, string>(deployment, deployedContract => {
    deploymentAddresses[decamelize(deployedContract.contractName).toUpperCase()] = deployedContract.contract.address;
    return "";
  });
  //console.log('deploymentAddresses: ', deploymentAddresses)
  fs.writeFileSync(addressesFile, JSON.stringify(deploymentAddresses, undefined, 4));
  console.log(`Saved deployment to "${addressesFile}".`);
};

const main = async () => {
  const deployer = await getDeployer();
  const chickenBondManagerAddress = deploymentAddresses["CHICKEN_BOND_MANAGER_ADDRESS"];
  const bondNFT = await getBondNFT(deployer, chickenBondManagerAddress);

  await initialChecks(deployer.address, bondNFT);

  const previousArtworkAddress = await bondNFT.artwork();

  const deployment = await deployNFTArtworkUpgrade(deployer, chickenBondManagerAddress, { log: true });

  const bondNFTArtworkSwitcherTester = getContractFactories(deployer).bondNFTArtworkSwitcherTester.factory
    .connect(deployer)
    .attach(deployment.bondNFTArtworkSwitcherTester.contract.address);

  assert(await bondNFTArtworkSwitcherTester.chickenBondManager(), chickenBondManagerAddress);
  assert(await bondNFTArtworkSwitcherTester.bondNFT(), bondNFT.address);
  assert(await bondNFTArtworkSwitcherTester.eggArtwork(), previousArtworkAddress);
  assert(await bondNFTArtworkSwitcherTester.chickenOutArtwork(), deployment.chickenOutArtwork.contract.address);
  assert(await bondNFTArtworkSwitcherTester.chickenInArtwork(), deployment.chickenInArtwork.contract.address);

  console.log();
  console.log("Deployment succeeded!");

  if (isVerify) {
    await verifyContracts(deployment);
  }

  if (!isNotCheck) {
    await generateAndCheckFinalNFTs(bondNFT, bondNFTArtworkSwitcherTester, numEggs);
  }

  // Set artwork !
  if (isSetArtwork) {
    await setNewArtworkAddress(deployment, bondNFT);
  }

  logMDReport(deployment);
  writeDeployment(deployment);

  console.log();

  rl.close();
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
