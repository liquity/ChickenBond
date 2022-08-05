import { BigNumber } from "@ethersproject/bignumber";
import { ContractReceipt, ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal, Decimalish } from "@liquity/lib-base";

import {
  connectToContracts,
  deployAndSetupContracts,
  LUSDChickenBondContracts,
  LUSDChickenBondDeploymentResult
} from "@liquity/lusd-chicken-bonds-bindings";

import { Pair } from ".";

const ONE_DAY = 24 * 60 * 60;

export interface LUSDChickenBondData extends Pair {
  bondID: number;
  startTime: number;
}

export interface LUSDChickenBondVaults {
  SP: number;
  curve: number;
}

export interface LUSDChickenBondBuckets {
  pendingSP: number;
  acquired: LUSDChickenBondVaults;
  permanent: number;
}

export interface LUSDChickenBondGlobalFunctions {
  deploy(): Promise<LUSDChickenBondDeploymentResult>;
  connect(user: Wallet): LUSDChickenBondContracts;

  loot(amount: Decimalish): Promise<void>;
  balance(address?: string): Promise<Pair>;
  allowance(spender?: string, owner?: string): Promise<number>;
  send(to: string, amount: Decimalish): Promise<void>;

  createBond(amount: Decimalish): Promise<number>;
  getBond(bondID?: number): Promise<LUSDChickenBondData>;
  chickenIn(bondID?: number): Promise<void>;
  chickenOut(bondID?: number): Promise<void>;
  redeem(amount: Decimalish): Promise<void>;
  redeemAll(): Promise<void>;

  shiftSPToCurve(amount: number): Promise<void>;
  shiftCurveToSP(amount: number): Promise<void>;

  backingRatio(): Promise<number>;
  buckets(): Promise<LUSDChickenBondBuckets>;

  // harvestSP(amount: number): Promise<void>;
  harvestCurve(amount: number): Promise<void>;

  trace(txHash: string): Promise<unknown>;
  warp(timestamp: number): Promise<unknown>;
  day(k: number): Promise<unknown>;
  mine(): Promise<unknown>;
  timestamp(): Promise<number>;
}

export interface LUSDChickenBondGlobals extends LUSDChickenBondGlobalFunctions {
  deployment: LUSDChickenBondDeploymentResult;
  contracts: LUSDChickenBondContracts;
  user: Wallet;
  bondID: number;
}

const receipt =
  <A extends unknown[]>(txFunc: (...args: A) => Promise<ContractTransaction>) =>
  (...args: A) =>
    txFunc(...args).then(tx => tx.wait());

const sequence = (
  first: () => Promise<ContractTransaction>,
  ...rest: ((prevReceipt: ContractReceipt) => Promise<ContractTransaction>)[]
) => rest.map(receipt).reduce((p, f) => p.then(f), receipt(first)());

const numberifyDecimal = (bn: BigNumber) => Number(Decimal.fromBigNumberString(bn.toHexString()));

export const getLUSDChickenBondGlobalFunctions = (
  globalObj: LUSDChickenBondGlobals,
  provider: JsonRpcProvider,
  deployer: Wallet
): LUSDChickenBondGlobalFunctions => ({
  async deploy(): Promise<LUSDChickenBondDeploymentResult> {
    globalObj.deployment = await deployAndSetupContracts(deployer, {
      log: true
      // config: {
      //   yearnGovernanceAddress: deployer.address // let us play around with migration ;-)
      // }
    });

    globalObj.connect(deployer);

    return globalObj.deployment;
  },

  connect(user): LUSDChickenBondContracts {
    globalObj.user = user.connect(provider);
    globalObj.contracts = connectToContracts(
      globalObj.user,
      globalObj.deployment.manifest.addresses
    );

    return globalObj.contracts;
  },

  async loot(amount) {
    await receipt(() =>
      globalObj.contracts.lusdToken.unprotectedMint(globalObj.user.address, Decimal.from(amount).hex)
    )();
  },

  async balance(address = globalObj.user.address) {
    const { lusdToken, bLUSDToken } = globalObj.contracts;

    const [lusdBalance, sLUSDBalance] = await Promise.all([
      lusdToken.balanceOf(address),
      bLUSDToken.balanceOf(address)
    ]);

    return {
      TOKEN: numberifyDecimal(lusdBalance),
      sTOKEN: numberifyDecimal(sLUSDBalance)
    };
  },

  allowance: (
    spender = globalObj.contracts.chickenBondManager.address,
    owner = globalObj.user.address
  ) => globalObj.contracts.lusdToken.allowance(owner, spender).then(numberifyDecimal),

  async send(to: string, amount: Decimalish) {
    await receipt(() => globalObj.contracts.lusdToken.transfer(to, Decimal.from(amount).hex))();
  },

  async createBond(amount): Promise<number> {
    const amountHex = Decimal.from(amount).hex;
    const { lusdToken, chickenBondManager, bondNFT } = globalObj.contracts;

    await sequence(
      () => lusdToken.unprotectedMint(globalObj.user.address, amountHex),
      () => lusdToken.approve(chickenBondManager.address, amountHex),
      () => chickenBondManager.createBond(amountHex)
    );

    const bondID = await bondNFT.totalSupply();
    return (globalObj.bondID = bondID.toNumber());
  },

  async getBond(bondID = globalObj.bondID): Promise<LUSDChickenBondData> {
    const { chickenBondManager } = globalObj.contracts;

    const [{ lusdAmount, startTime }, accruedBLUSD] = await Promise.all([
      chickenBondManager.getBondData(bondID),
      chickenBondManager.calcAccruedBLUSD(bondID)
    ]);

    return {
      bondID,
      startTime: startTime.toNumber(),
      TOKEN: numberifyDecimal(lusdAmount),
      sTOKEN: numberifyDecimal(accruedBLUSD)
    };
  },

  async chickenIn(bondID = globalObj.bondID) {
    await receipt(() => globalObj.contracts.chickenBondManager.chickenIn(bondID))();
  },

  async chickenOut(bondID = globalObj.bondID) {
    await receipt(() =>
      globalObj.contracts.chickenBondManager.chickenOut(bondID, Decimal.ZERO.hex)
    )();
  },

  async redeem(amount) {
    await receipt(() =>
      globalObj.contracts.chickenBondManager.redeem(Decimal.from(amount).hex, Decimal.ZERO.hex)
    )();
  },

  async redeemAll() {
    const { chickenBondManager, bLUSDToken } = globalObj.contracts;

    await receipt(async () =>
      chickenBondManager.redeem(await bLUSDToken.balanceOf(globalObj.user.address), Decimal.ZERO.hex)
    )();
  },

  async shiftSPToCurve(amount) {
    const { chickenBondManager, curvePool } = globalObj.contracts;

    await sequence(
      () => curvePool.setNextPrankPrice(Decimal.from(1.01).hex),
      () => chickenBondManager.shiftLUSDFromSPToCurve(Decimal.from(amount).hex)
    );
  },

  async shiftCurveToSP(amount) {
    const { chickenBondManager, curvePool } = globalObj.contracts;

    await sequence(
      () => curvePool.setNextPrankPrice(Decimal.from(0.99).hex),
      () => chickenBondManager.shiftLUSDFromCurveToSP(Decimal.from(amount).hex)
    );
  },

  backingRatio: () =>
    globalObj.contracts.chickenBondManager.calcSystemBackingRatio().then(numberifyDecimal),

  async buckets(): Promise<LUSDChickenBondBuckets> {
    const { chickenBondManager } = globalObj.contracts;

    const [pendingSP, acquiredSP, acquiredCurve, permanent] = await Promise.all([
      chickenBondManager.getPendingLUSD().then(numberifyDecimal),
      chickenBondManager.getAcquiredLUSDInSP().then(numberifyDecimal),
      chickenBondManager.getAcquiredLUSDInCurve().then(numberifyDecimal),
      chickenBondManager.getPermanentLUSD().then(numberifyDecimal)
    ]);

    return {
      pendingSP,
      acquired: {
        SP: acquiredSP,
        curve: acquiredCurve
      },
      permanent
    };
  },

  // async harvestSP(amount) {
  //   await receipt(() => globalObj.contracts.bammSPVault.harvest(Decimal.from(amount).hex))();
  // },

  async harvestCurve(amount) {
    await receipt(() => globalObj.contracts.yearnCurveVault.harvest(Decimal.from(amount).hex))();
  },

  trace: txHash => provider.send("trace_transaction", [txHash]),
  warp: timestamp => provider.send("evm_setNextBlockTimestamp", ["0x" + timestamp.toString(16)]),
  day: k => globalObj.warp(globalObj.deployment.manifest.deploymentTimestamp + k * ONE_DAY),
  mine: () => provider.send("evm_mine", []),

  timestamp: () =>
    provider
      .call({
        data:
          "0x" +
          "42" + //// TIMESTAMP
          "6000" + // PUSH1 0
          "52" + //// MSTORE
          "6004" + // PUSH1 4
          "601c" + // PUSH1 28
          "F3" ////// RETURN
      })
      .then(x => parseInt(x, 16))
});
