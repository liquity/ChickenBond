import fs from "fs-extra";
import path from "path";

import { ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal } from "@liquity/lib-base";

import { deployAndSetupContracts } from "../src/deployment";
import { connectToContracts, LUSDChickenBondContractAddresses } from "../src/contracts";

const outDir = "tmp";
const outFile = "deployment.json";
const outPath = path.join(outDir, outFile);

const defaultRpcUrl = "http://127.0.0.1:8545";

const deployerPrivateKeyChain = [
  // The only initial account on OpenEthereum's dev chain
  "0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7",
  // Account #1 on Hardhat/Anvil
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
];

const txWait = (tx: ContractTransaction) => tx.wait();

const runSmokeTest = async (wallet: Wallet, addresses: LUSDChickenBondContractAddresses) => {
  const { lusdToken, chickenBondManager } = connectToContracts(wallet, addresses);
  const bondLUSDAmount = Decimal.from(100).hex;

  await lusdToken.tap().then(txWait);
  await lusdToken.approve(chickenBondManager.address, bondLUSDAmount).then(txWait);
  await chickenBondManager.createBond(bondLUSDAmount).then(txWait);
};

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

const main = async () => {
  const deployer = await getDeployer();
  console.log();

  const deployment = await deployAndSetupContracts(deployer, {
    log: true,
    config: {
      // This will let us test migration on testnet
      yearnGovernanceAddress: deployer.address
    }
  });

  console.log();
  console.log("Deployment succeeded! Manifest:");
  console.log(deployment.manifest);

  if (process.argv.includes("--smoke-test")) {
    console.log();
    console.log("Running smoke test ...");
    await runSmokeTest(deployer, deployment.manifest.addresses);
    console.log("Smoke test succeeded!");
  }

  if (process.argv.includes("--save")) {
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(deployment.manifest, undefined, 2));

    console.log();
    console.log(`Saved deployment manifest to "${outPath}".`);
  }
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
