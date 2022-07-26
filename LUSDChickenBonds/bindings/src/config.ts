import { BigNumber } from "@ethersproject/bignumber";
import { AddressZero } from "@ethersproject/constants";

export interface LUSDChickenBondConfig {
  targetAverageAgeSeconds: BigNumber;
  initialAccrualParameter: BigNumber;
  minimumAccrualParameter: BigNumber;
  accrualAdjustmentRate: BigNumber;
  accrualAdjustmentPeriodSeconds: BigNumber;
  chickenInAMMFee: BigNumber;
  curveDepositDydxThreshold: BigNumber;
  curveWithdrawalDxdyThreshold: BigNumber;
  bootstrapPeriodChickenIn: BigNumber;
  bootstrapPeriodRedeem: BigNumber;
  bootstrapPeriodShift: BigNumber;
  shifterDelay: BigNumber;
  shifterWindow: BigNumber;
  minBLUSDSupply: BigNumber;
  minBondAmount: BigNumber;
  redemptionFeeBeta: BigNumber;
  redemptionFeeMinuteDecayFactor: BigNumber;
  yearnGovernanceAddress: string;
}

export const defaultConfig: Readonly<LUSDChickenBondConfig> = {
  targetAverageAgeSeconds: BigNumber.from("2592000"),
  initialAccrualParameter: BigNumber.from("2592000000000000000000000"),
  minimumAccrualParameter: BigNumber.from("2592000000000000000000"),
  accrualAdjustmentRate: BigNumber.from("10000000000000000"),
  accrualAdjustmentPeriodSeconds: BigNumber.from("86400"),
  chickenInAMMFee: BigNumber.from("10000000000000000"),
  curveDepositDydxThreshold: BigNumber.from("1000000000000000000"),
  curveWithdrawalDxdyThreshold: BigNumber.from("10000000000000000"),
  bootstrapPeriodChickenIn: BigNumber.from("604800"),
  bootstrapPeriodRedeem: BigNumber.from("604800"),
  bootstrapPeriodShift: BigNumber.from("7776000"),
  shifterDelay: BigNumber.from("3600"),
  shifterWindow: BigNumber.from("600"),
  minBLUSDSupply: BigNumber.from("1000000000000000000"),
  minBondAmount: BigNumber.from("100000000000000000000"),
  redemptionFeeBeta: BigNumber.from("2"),
  redemptionFeeMinuteDecayFactor: BigNumber.from("999037758833783000"),
  yearnGovernanceAddress: AddressZero
};

const mapConfig = (
  r: Readonly<LUSDChickenBondConfig>,
  f: <K extends keyof LUSDChickenBondConfig>(
    k: K,
    v: LUSDChickenBondConfig[K]
  ) => LUSDChickenBondConfig[K]
) =>
  Object.fromEntries(
    Object.entries(r).map(([k, v]) => [k, f(k as keyof LUSDChickenBondConfig, v)])
  ) as unknown as LUSDChickenBondConfig;

export const fillConfig = (config?: Readonly<Partial<LUSDChickenBondConfig>>) =>
  mapConfig(
    defaultConfig,
    (paramName, defaultValue) => (config && config[paramName]) ?? defaultValue
  );
