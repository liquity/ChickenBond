import assert from "assert";
import { ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";

import { connectToContracts } from "../src/contracts";
import testnet from "../deployments/goerli.json";

const numUnderlings = 100;

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const requireEnv = (name: string): string =>
  process.env[name] || panic(`${name} missing from environment`);

const txWait = (tx: ContractTransaction) => tx.wait();

const provider = new JsonRpcProvider(requireEnv("RPC_URL"));
const harvester = new Wallet(requireEnv("PRIVATE_KEY"), provider);

const { prankster } = connectToContracts(harvester, testnet.addresses);

const main = async () => {
  const actualNetwork = await provider.getNetwork();

  if (actualNetwork.chainId !== testnet.chainId) {
    throw new Error(`Wrong network (got ${actualNetwork.chainId}, expected ${testnet.chainId})`);
  }

  const numUnderlingsBefore = await prankster.numUnderlings();
  assert(numUnderlingsBefore.isZero(), "Underlings already spawned");

  await prankster.spawn(numUnderlings / 2).then(txWait);
  await prankster.spawn(numUnderlings / 2).then(txWait);

  const numUnderlingsAfter = await prankster.numUnderlings();
  assert(
    numUnderlingsAfter.eq(numUnderlings),
    `expected ${numUnderlings} Underlings, got ${numUnderlingsAfter}`
  );
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
