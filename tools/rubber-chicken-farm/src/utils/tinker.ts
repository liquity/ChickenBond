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

const ONE_DAY = 24 * 60 * 60;

export interface LUSDChickenBondTokenPair {
  LUSD: number;
  bLUSD: number;
}

const statuses = ["nonExistent", "active", "chickenedOut", "chickenedIn"] as const;

export type LUSDChickenBondStatus = typeof statuses[number];

const lookupStatus = (status: number): LUSDChickenBondStatus => statuses[status];

export interface LUSDChickenBondData extends LUSDChickenBondTokenPair {
  bondID: number;
  startTime: number;
  endTime: number;
  initialHalfDna: string;
  finalHalfDna: string;
  status: LUSDChickenBondStatus;
}

export interface LUSDChickenBondBuckets {
  pendingSP: number;
  acquiredSP: number;
  acquiredCurve: number;
  permanent: number;
}

export interface LUSDChickenBondGlobalFunctions {
  deploy(): Promise<LUSDChickenBondDeploymentResult>;
  connect(user: Wallet): LUSDChickenBondContracts;

  tap(): Promise<void>;
  balance(address?: string): Promise<LUSDChickenBondTokenPair>;
  allowance(spender?: string, owner?: string): Promise<number>;
  send(to: string, amount: Decimalish): Promise<void>;

  bond(bondID?: number): Promise<LUSDChickenBondData>;

  createBond(amount: Decimalish): Promise<number>;
  chickenIn(bondID?: number): Promise<void>;
  chickenOut(bondID?: number): Promise<void>;

  redeem(amount: Decimalish): Promise<void>;
  redeemAll(): Promise<void>;

  shiftSPToCurve(amount: number): Promise<void>;
  shiftCurveToSP(amount: number): Promise<void>;

  backingRatio(): Promise<number>;
  buckets(): Promise<LUSDChickenBondBuckets>;

  harvest(): Promise<void>;

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

  async tap() {
    await receipt(() => globalObj.contracts.lusdToken.tap())();
  },

  async balance(address = globalObj.user.address) {
    const { lusdToken, bLUSDToken } = globalObj.contracts;

    const [lusdBalance, bLUSDBalance] = await Promise.all([
      lusdToken.balanceOf(address),
      bLUSDToken.balanceOf(address)
    ]);

    return {
      LUSD: numberifyDecimal(lusdBalance),
      bLUSD: numberifyDecimal(bLUSDBalance)
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
      () => lusdToken.approve(chickenBondManager.address, amountHex),
      () => chickenBondManager.createBond(amountHex)
    );

    const bondID = await bondNFT.totalSupply();
    return (globalObj.bondID = bondID.toNumber());
  },

  async bond(bondID = globalObj.bondID): Promise<LUSDChickenBondData> {
    const { chickenBondManager } = globalObj.contracts;

    const [bondData, accruedBLUSD] = await Promise.all([
      chickenBondManager.getBondData(bondID),
      chickenBondManager.calcAccruedBLUSD(bondID)
    ]);

    return {
      bondID,
      LUSD: numberifyDecimal(bondData.lusdAmount),
      bLUSD: numberifyDecimal(accruedBLUSD),
      startTime: bondData.startTime.toNumber(),
      endTime: bondData.endTime.toNumber(),
      initialHalfDna: bondData.initialHalfDna.toHexString(),
      finalHalfDna: bondData.finalHalfDna.toHexString(),
      status: lookupStatus(bondData.status)
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
      acquiredSP,
      acquiredCurve,
      permanent
    };
  },

  async harvest() {
    await receipt(() => globalObj.contracts.harvester.harvest())();
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
