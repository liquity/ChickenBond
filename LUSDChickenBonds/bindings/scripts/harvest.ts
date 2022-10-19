import { BigNumber } from "@ethersproject/bignumber";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal } from "@liquity/lib-base";

import { connectToContracts } from "../src/contracts";
import testnet from "../deployments/goerli.json";

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const requireEnv = (name: string): string =>
  process.env[name] || panic(`${name} missing from environment`);

const numberify = (n: BigNumber) => Number(Decimal.fromBigNumberString(n.toHexString()));

const provider = new JsonRpcProvider(requireEnv("RPC_URL"));
const harvester = new Wallet(requireEnv("PRIVATE_KEY"), provider);

const { prankster, bLUSDCurvePool, chickenBondManager } = connectToContracts(
  harvester,
  testnet.addresses
);

const getMarketPrice = async () => {
  try {
    return numberify(await bLUSDCurvePool.get_dy(0, 1, Decimal.ONE.hex));
  } catch {
    return 1 / numberify(await bLUSDCurvePool.price_oracle());
  }
};

const getSqrtEffLambda = async () => {
  const [marketPrice, redemptionPrice, chickenInFee] = await Promise.all([
    getMarketPrice(),
    chickenBondManager.calcSystemBackingRatio().then(numberify),
    chickenBondManager.CHICKEN_IN_AMM_FEE().then(numberify)
  ]);

  const lambda = marketPrice / redemptionPrice;
  const effLambda = lambda * (1 - chickenInFee);

  return Math.sqrt(effLambda);
};

const randInt = (ceil: number) => Math.floor(ceil * Math.random());

const permute = (n: number) => {
  const arr = [...new Array<number>(n).keys()];

  for (let i = 0; i < n - 1; i++) {
    const j = i + randInt(n - i);
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }

  return arr;
};

const main = async () => {
  const [
    actualNetwork
    // txCount,
    // numUnderlings,
    // sqrtEffLambda
  ] = await Promise.all([
    provider.getNetwork()
    // harvester.getTransactionCount(),
    // prankster.numUnderlings(),
    // getSqrtEffLambda()
  ]);

  if (actualNetwork.chainId !== testnet.chainId) {
    throw new Error(`Wrong network (got ${actualNetwork.chainId}, expected ${testnet.chainId})`);
  }

  // // Don't wait for inclusion, just broadcast both TXs
  // await prankster.whip(
  //   permute(numUnderlings.toNumber()).slice(0, 10),
  //   Decimal.from(sqrtEffLambda).hex,
  //   {
  //     gasLimit: 8000000,
  //     nonce: txCount
  //   }
  // );

  await prankster.harvest({
    // nonce: txCount + 1
  });
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
