import { BigNumber } from "@ethersproject/bignumber";

export interface LUSDChickenBondConfig {
  targetAverageAgeSeconds: BigNumber;
  initialAccrualParameter: BigNumber;
  minimumAccrualParameter: BigNumber;
  accrualAdjustmentRate: BigNumber;
  accrualAdjustmentPeriodSeconds: BigNumber;
  chickenInAMMTax: BigNumber;
}

export const defaultConfig: Readonly<LUSDChickenBondConfig> = {
  targetAverageAgeSeconds: BigNumber.from("2592000"),
  initialAccrualParameter: BigNumber.from("2592000000000000000000000"),
  minimumAccrualParameter: BigNumber.from("2592000000000000000000"),
  accrualAdjustmentRate: BigNumber.from("10000000000000000"),
  accrualAdjustmentPeriodSeconds: BigNumber.from("86400"),
  chickenInAMMTax: BigNumber.from("10000000000000000")
};

const mapRecordValues = <K extends string, V, W>(r: Record<K, V>, f: (k: K, v: V) => W) =>
  Object.fromEntries(Object.entries(r).map(([k, v]) => [k, f(k as K, v as V)])) as Record<K, W>;

export const fillConfig = (
  config?: Readonly<Partial<LUSDChickenBondConfig>>
): LUSDChickenBondConfig =>
  mapRecordValues(
    defaultConfig,
    (paramName, defaultValue) => (config && config[paramName]) ?? defaultValue
  );
