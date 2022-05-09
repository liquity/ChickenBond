import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { deployAndSetupContracts } from "../src/deployment";

const jsonRpcUrl = "http://127.0.0.1:8545";

const deployerPrivateKeyChain = [
  // The only initial account on OpenEthereum's dev chain
  "0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7",
  // Account #1 on Hardhat/Anvil
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
];

const main = async () => {
  const provider = new JsonRpcProvider(jsonRpcUrl);

  const deployers = await Promise.all(
    deployerPrivateKeyChain
      .map(deployerPrivateKey => new Wallet(deployerPrivateKey, provider))
      .map((wallet, i) => wallet.getBalance().then(balance => ({ balance, wallet, i })))
  );

  const deployer = deployers.find(({ balance }) => !balance.isZero());

  if (!deployer) {
    throw new Error("neither private key holds any Ether");
  }

  console.log(`Using key #${deployer.i + 1} ...`);
  console.log();
  const deployment = await deployAndSetupContracts(deployer.wallet, { log: true });
  console.log();
  console.log("Deployment succeeded! Manifest:");
  console.log(deployment.manifest);
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
