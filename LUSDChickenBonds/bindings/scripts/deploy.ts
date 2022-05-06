import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { deployAndSetupContracts, setSilent } from "../src/deployment";

const jsonRpcUrl = "http://127.0.0.1:8545";
// Private key of the only initial account on OpenEthereum's dev chain
const deployerPrivateKey = "0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7";

const main = async () => {
  const provider = new JsonRpcProvider(jsonRpcUrl);
  const deployer = new Wallet(deployerPrivateKey, provider);

  setSilent(false);

  const deployment = await deployAndSetupContracts(deployer);

  console.log("Deployment succeeded! Manifest:");
  console.log(deployment.manifest);
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
