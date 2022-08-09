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

export interface LUSDChickenBondBalances extends LUSDChickenBondTokenPair {
  LP: number;
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
  balance(address?: string): Promise<LUSDChickenBondBalances>;
  allowance(spender?: string, owner?: string): Promise<number>;
  send(to: string, amount: Decimalish): Promise<void>;

  bond(bondID?: number): Promise<LUSDChickenBondData>;
  backingRatio(): Promise<number>;
  buckets(): Promise<LUSDChickenBondBuckets>;

  createBond(amount: Decimalish): Promise<number>;
  chickenIn(bondID?: number): Promise<void>;
  chickenOut(bondID?: number): Promise<void>;

  redeem(amount: Decimalish): Promise<void>;
  redeemAll(): Promise<void>;

  migrate(): Promise<void>;

  shiftCountdown(): Promise<void>;
  shiftSPToCurve(amount: number): Promise<void>;
  shiftCurveToSP(amount: number): Promise<void>;

  spot(): Promise<number>;
  deposit(bLUSDAmount?: number, lusdAmount?: number): Promise<void>;
  withdraw(LP?: number): Promise<void>;
  swapLUSD(amount?: number): Promise<void>;
  swapBLUSD(amount?: number): Promise<void>;

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
      log: true,
      config: {
        yearnGovernanceAddress: deployer.address // let us play around with migration ;-)
      }
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
    const { lusdToken, bLUSDToken, bLUSDCurveToken } = globalObj.contracts;

    const [LUSD, bLUSD, LP] = await Promise.all([
      lusdToken.balanceOf(address),
      bLUSDToken.balanceOf(address),
      bLUSDCurveToken.balanceOf(address)
    ]);

    return {
      LUSD: numberifyDecimal(LUSD),
      bLUSD: numberifyDecimal(bLUSD),
      LP: numberifyDecimal(LP)
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

  async migrate() {
    await receipt(() => globalObj.contracts.chickenBondManager.activateMigration())();
  },

  async shiftCountdown() {
    await receipt(() => globalObj.contracts.chickenBondManager.startShifterCountdown())();
  },

  async shiftSPToCurve(amount) {
    await receipt(() =>
      globalObj.contracts.prankster.shiftLUSDFromSPToCurve(Decimal.from(amount).hex)
    )();
  },

  async shiftCurveToSP(amount) {
    await receipt(() =>
      globalObj.contracts.prankster.shiftLUSDFromCurveToSP(Decimal.from(amount).hex)
    )();
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

  spot: () => globalObj.contracts.bLUSDCurvePool.get_dy(0, 1, 1).then(numberifyDecimal),

  async deposit(bLUSDAmount, lusdAmount) {
    const { lusdToken, bLUSDToken, bLUSDCurvePool } = globalObj.contracts;

    const dBLUSDAmount = bLUSDAmount
      ? Decimal.from(bLUSDAmount)
      : Decimal.fromBigNumberString(
          (await bLUSDToken.balanceOf(globalObj.user.address)).toHexString()
        );

    const dLUSDAmount = lusdAmount ? Decimal.from(lusdAmount) : dBLUSDAmount.mul(1.2);

    await sequence(
      () => lusdToken.approve(bLUSDCurvePool.address, dLUSDAmount.hex),
      () => bLUSDToken.approve(bLUSDCurvePool.address, dBLUSDAmount.hex),
      () =>
        bLUSDCurvePool["add_liquidity(uint256[2],uint256)"]([dBLUSDAmount.hex, dLUSDAmount.hex], 0)
    );
  },

  async withdraw(LP) {
    const { bLUSDCurveToken, bLUSDCurvePool } = globalObj.contracts;

    const dLP = LP
      ? Decimal.from(LP)
      : Decimal.fromBigNumberString(
          (await bLUSDCurveToken.balanceOf(globalObj.user.address)).toHexString()
        );

    await bLUSDCurvePool["remove_liquidity(uint256,uint256[2])"](dLP.hex, [0, 0]);
  },

  async swapLUSD(amount) {
    const { lusdToken, bLUSDCurvePool } = globalObj.contracts;

    const dLUSDAmount = amount
      ? Decimal.from(amount)
      : Decimal.fromBigNumberString(
          (await lusdToken.balanceOf(globalObj.user.address)).toHexString()
        );

    await sequence(
      () => lusdToken.approve(bLUSDCurvePool.address, dLUSDAmount.hex),
      () => bLUSDCurvePool["exchange(uint256,uint256,uint256,uint256)"](1, 0, dLUSDAmount.hex, 0)
    );
  },

  async swapBLUSD(amount) {
    const { bLUSDToken, bLUSDCurvePool } = globalObj.contracts;

    const dBLUSDAmount = amount
      ? Decimal.from(amount)
      : Decimal.fromBigNumberString(
          (await bLUSDToken.balanceOf(globalObj.user.address)).toHexString()
        );

    await sequence(
      () => bLUSDToken.approve(bLUSDCurvePool.address, dBLUSDAmount.hex),
      () => bLUSDCurvePool["exchange(uint256,uint256,uint256,uint256)"](0, 1, dBLUSDAmount.hex, 0)
    );
  },

  async harvest() {
    await receipt(() => globalObj.contracts.prankster.harvest())();
  },

  trace: txHash => provider.send("trace_transaction", [txHash]),
  warp: timestamp => provider.send("evm_setNextBlockTimestamp", [timestamp]),
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
