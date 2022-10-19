import assert from "assert";
import fs from "fs-extra";
import path from "path";

import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { MaxUint256 } from "@ethersproject/constants";
import { ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal, Decimalish } from "@liquity/lib-base";

import { deployAndSetupContracts } from "../src/deployment";
import { connectToContracts } from "../src/contracts";
import { writeNFT, checkMetadata } from "../src/NFTHelpers";

const numEggs = 1000;
const outDir = path.join("tmp", "fuzzy-eggs");
const svgDir = path.join(outDir, "svg");
const jsonDir = path.join(outDir, "json");

fs.removeSync(outDir);
fs.mkdirSync(svgDir, { recursive: true });
fs.mkdirSync(jsonDir, { recursive: true });

const provider = new JsonRpcProvider("http://localhost:8545");

const deployer = new Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider
);

const txWait = (tx: ContractTransaction) => tx.wait();

const warp = (timestamp: number) => provider.send("evm_setNextBlockTimestamp", [timestamp]);

const main = async () => {
  const deployment = await deployAndSetupContracts(deployer, {
    log: true,
    config: {
      // Ample LUSD
      lusdFaucetTapAmount: BigNumber.from(Decimal.from(1000000000).hex)
    }
  });

  const { lusdToken, bondNFT, chickenBondManager, lqtyStaking, troveManager, curveGaugeController } =
    connectToContracts(deployer, deployment.manifest.addresses);

  const createBond = async (amount: Decimalish) => {
    await chickenBondManager.createBond(Decimal.from(amount).hex).then(txWait);
    return bondNFT.totalSupply();
  };

  const chickenIn = (bondID: BigNumberish) => chickenBondManager.chickenIn(bondID).then(txWait);
  const chickenOut = (bondID: BigNumberish) => chickenBondManager.chickenOut(bondID, 0).then(txWait);

  const setMocks = async (lqty: Decimalish, trove: Decimalish, llama: Decimalish) => {
    await lqtyStaking.setStake(Decimal.from(lqty).hex).then(txWait);
    await troveManager.setTroveDebt(Decimal.from(trove).hex).then(txWait);
    await curveGaugeController.setSlope(Decimal.from(llama).hex).then(txWait);
  };

  // Enable chicken-ins

  await lusdToken.tap().then(txWait);
  await lusdToken.approve(chickenBondManager.address, MaxUint256).then(txWait);
  await createBond(100);

  const { startTime } = await chickenBondManager.getBondData(1);
  const bootstrap = await chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN();

  await warp(startTime.add(bootstrap).toNumber());
  await chickenIn(1);

  // Main loop

  for (let i = 1; i <= numEggs; ++i) {
    console.log(`Egg ${i}`);

    const amount = 100 + 120000 * Math.random();
    const bondID = await createBond(amount);
    const eggTokenURI = await bondNFT.tokenURI(bondID);

    const eggMetadata = await writeNFT(bondID, eggTokenURI, jsonDir, svgDir, "1-egg");

    let finalMetadata;
    let finalTokenURI;
    if (Math.random() < 0.33) {
      await chickenOut(bondID);
      finalTokenURI = await bondNFT.tokenURI(bondID);
      finalMetadata = await writeNFT(bondID, finalTokenURI, jsonDir, svgDir, "2-chicken-out");
    } else {
      await setMocks(
        Math.random() < 0.33 ? 0 : 1,
        Math.random() < 0.33 ? 0 : 200 + 1000000 * Math.random(),
        Math.random() < 0.33 ? 0 : 1
      );

      await chickenIn(bondID);
      finalTokenURI = await bondNFT.tokenURI(bondID);
      finalMetadata = await writeNFT(bondID, finalTokenURI, jsonDir, svgDir, "2-chicken-in");
    }

    checkMetadata(eggMetadata, finalMetadata);
  }
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
