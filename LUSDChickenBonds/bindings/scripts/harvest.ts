import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { connectToContracts } from "../src/contracts";
import goerli from "../deployments/goerli.json";

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const requireEnv = (name: string): string =>
  process.env[name] || panic(`${name} missing from environment`);

const provider = new JsonRpcProvider(requireEnv("RPC_URL"));
const harvester = new Wallet(requireEnv("PRIVATE_KEY"), provider);
const { prankster } = connectToContracts(harvester, goerli.addresses);

prankster.harvest().catch(err => {
  console.error(err);
  process.exit(1);
});
