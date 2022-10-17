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

  const writeEgg = async (bondID: BigNumberish, fileSuffix: string) => {
    const expectedTokenURIScheme = "data:application/json;base64,";
    const expectedImageURIScheme = "data:image/svg+xml;base64,";

    const tokenURI = await bondNFT.tokenURI(bondID);
    assert(tokenURI.startsWith(expectedTokenURIScheme));

    const metadata = JSON.parse(
      Buffer.from(tokenURI.replace(expectedTokenURIScheme, ""), "base64").toString()
    );

    const imageURI = metadata.image;
    assert(typeof imageURI === "string");
    assert(imageURI.startsWith(expectedImageURIScheme));

    const svg = Buffer.from(imageURI.replace(expectedImageURIScheme, ""), "base64").toString();

    fs.writeFileSync(
      path.join(jsonDir, `${bondID}-${fileSuffix}.json`),
      JSON.stringify(metadata, null, 2)
    );

    fs.writeFileSync(path.join(svgDir, `${bondID}-${fileSuffix}.svg`), svg);

    return metadata;
  };

  const findAttributeValue = (metadata: any, attributeKey: string) => {
    for (const attribute of metadata.attributes) {
      if (attribute.trait_type === attributeKey) {
        return attribute.value;
      }
    }
    return null;
  };

  const checkAttribute = (eggMetadata: object, finalMetadata: object, attributeKey: string, optional: boolean = false) => {
    const finalAttribute = findAttributeValue(finalMetadata, attributeKey);;
    if (optional && !finalAttribute) { return true; }

    const eggAttribute = findAttributeValue(eggMetadata, attributeKey);

    if (eggAttribute === finalAttribute) {
      return true;
    }

    console.log('eggAttribute:   ', eggAttribute)
    console.log('finalAttribute: ', eggAttribute)
    return false;
  };

  const checkMetadata = (eggMetadata: object, finalMetadata: object) => {
    //const attributesToCheck = ["Border", "Card"]
    // Border
    assert(checkAttribute(eggMetadata, finalMetadata, "Border"));
    // Card
    assert(checkAttribute(eggMetadata, finalMetadata, "Card"));
    // Shell
    assert(checkAttribute(eggMetadata, finalMetadata, "Shell", true));
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

    const eggMetadata = await writeEgg(bondID, "1-egg");

    let finalMetadata;
    if (Math.random() < 0.33) {
      await chickenOut(bondID);
      finalMetadata = await writeEgg(bondID, "2-chicken-out");
    } else {
      await setMocks(
        Math.random() < 0.33 ? 0 : 1,
        Math.random() < 0.33 ? 0 : 200 + 1000000 * Math.random(),
        Math.random() < 0.33 ? 0 : 1
      );

      await chickenIn(bondID);
      finalMetadata = await writeEgg(bondID, "2-chicken-in");
    }

    checkMetadata(eggMetadata, finalMetadata);
  }
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
