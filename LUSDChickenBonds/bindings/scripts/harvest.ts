import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { connectToContracts } from "../src/contracts";
import testnet from "../deployments/goerli.json";

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const requireEnv = (name: string): string =>
  process.env[name] || panic(`${name} missing from environment`);

const provider = new JsonRpcProvider(requireEnv("RPC_URL"));
const harvester = new Wallet(requireEnv("PRIVATE_KEY"), provider);
const { prankster } = connectToContracts(harvester, testnet.addresses);

provider
  .getNetwork()
  .then(actualNetwork => {
    if (actualNetwork.chainId !== testnet.chainId) {
      throw new Error(`Wrong network (got ${actualNetwork.chainId}, expected ${testnet.chainId})`);
    }
  })
  .then(() => prankster.harvest())
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
