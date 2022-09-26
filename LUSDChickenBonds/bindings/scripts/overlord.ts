import { BigNumber } from "@ethersproject/bignumber";
import { ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal } from "@liquity/lib-base";

import { deployAndSetupContracts } from "../src/deployment";
import { connectToContracts } from "../src/contracts";

const numUnderlings = 100;
const numRuns = 500;

const provider = new JsonRpcProvider("http://localhost:8545");

const deployer = new Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider
);

const numberify = (n: BigNumber) => Number(Decimal.fromBigNumberString(n.toHexString()));

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

const txWait = (tx: ContractTransaction) => tx.wait();

const warp = (timestamp: number) => provider.send("evm_setNextBlockTimestamp", [timestamp]);

const main = async () => {
  const deployment = await deployAndSetupContracts(deployer, { log: true });

  const {
    prankster,
    lusdToken,
    chickenBondManager,
    bLUSDToken,
    bLUSDCurvePool,
    bLUSDCurveToken,
    curveLiquidityGauge
  } = connectToContracts(deployer, deployment.manifest.addresses);

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

  const day = (k: number) =>
    warp(deployment.manifest.deploymentTimestamp + k * deployment.config.realSecondsPerFakeDay);

  const spawn = (n: number) => prankster.spawn(n).then(txWait);

  const harvest = () => prankster.harvest().then(txWait);

  const whip = async (n: number) =>
    prankster
      .whip(permute(numUnderlings).slice(0, n), Decimal.from(await getSqrtEffLambda()).hex, {
        gasLimit: 8000000
      })
      .then(txWait)
      .then(tx => console.log("gas used:", tx.gasUsed.toNumber()));

  // ========= Main logic ============

  await spawn(numUnderlings / 2);
  await spawn(numUnderlings / 2);

  for (let i = 1; i < numRuns; ++i) {
    console.log("day", Math.floor(i / 4));
    await day(i / 4);
    await harvest();
    await whip(10);
  }

  // ========= Final stats ===========

  const pending = numberify(await chickenBondManager.getPendingLUSD());
  const acquired = numberify(await chickenBondManager.getTotalAcquiredLUSD());
  const permanent = numberify(await chickenBondManager.getPermanentLUSD());
  const bLUSDSupply = numberify(await bLUSDToken.totalSupply());
  const oraclePrice = 1 / numberify(await bLUSDCurvePool.price_oracle());
  const lpPrice = oraclePrice * numberify(await bLUSDCurvePool.lp_price());
  const lpSupply = numberify(await bLUSDCurveToken.totalSupply());
  const lpReward = numberify(await lusdToken.balanceOf(curveLiquidityGauge.address));

  console.log();
  console.log("pending:", pending);
  console.log("acquired:", acquired);
  console.log("permanent:", permanent);
  console.log("bLUSD supply:", bLUSDSupply);
  console.log("bLUSD oracle price:", oraclePrice);
  console.log("bLUSD spot price:", numberify(await bLUSDCurvePool.get_dy(0, 1, Decimal.ONE.hex)));

  console.log(
    "bLUSD redemption price:",
    numberify(await chickenBondManager.calcSystemBackingRatio())
  );

  console.log(
    "bLUSD fair range:",
    (acquired + permanent) / bLUSDSupply,
    "-",
    (pending + acquired + permanent) / bLUSDSupply
  );

  console.log("LP reward:", lpReward);
  console.log("LP reward APR:", 100 * (lpReward / lpPrice / lpSupply) * ((365 * 4) / numRuns), "%");

  console.log(
    "bonding APR:",
    100 *
      ((bLUSDSupply * oraclePrice) / (acquired + permanent + lpReward) - 1) *
      ((365 * 4) / numRuns),
    "%"
  );
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
