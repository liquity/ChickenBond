import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { connectToContracts } from "../src/contracts";
import rinkeby from "../deployments/rinkeby.json";

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const requireEnv = (name: string): string =>
  process.env[name] || panic(`${name} missing from environment`);

const provider = new JsonRpcProvider(requireEnv("RPC_URL"));
const harvester = new Wallet(requireEnv("PRIVATE_KEY"), provider);
const { prankster } = connectToContracts(harvester, rinkeby.addresses);

provider
  .getNetwork()
  .then(actualNetwork => {
    if (actualNetwork.chainId !== rinkeby.chainId) {
      throw new Error("Wrong network (should be Rinkeby)");
    }
  })
  .then(() => prankster.harvest())
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
