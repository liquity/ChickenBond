import { BigNumber } from "@ethersproject/bignumber";
import { AddressZero } from "@ethersproject/constants";

export interface LUSDChickenBondConfig {
  targetAverageAgeSeconds: BigNumber;
  initialAccrualParameter: BigNumber;
  minimumAccrualParameter: BigNumber;
  accrualAdjustmentRate: BigNumber;
  accrualAdjustmentPeriodSeconds: BigNumber;
  chickenInAMMTax: BigNumber;
  curveDepositDydxThreshold: BigNumber;
  curveWithdrawalDxdyThreshold: BigNumber;
  bondNFTTransferLockoutPeriodSeconds: BigNumber;
  yearnGovernanceAddress: string;
}

export const defaultConfig: Readonly<LUSDChickenBondConfig> = {
  targetAverageAgeSeconds: BigNumber.from("2592000"),
  initialAccrualParameter: BigNumber.from("2592000000000000000000000"),
  minimumAccrualParameter: BigNumber.from("2592000000000000000000"),
  accrualAdjustmentRate: BigNumber.from("10000000000000000"),
  accrualAdjustmentPeriodSeconds: BigNumber.from("86400"),
  chickenInAMMTax: BigNumber.from("10000000000000000"),
  curveDepositDydxThreshold: BigNumber.from("1000000000000000000"),
  curveWithdrawalDxdyThreshold: BigNumber.from("10000000000000000"),
  bondNFTTransferLockoutPeriodSeconds: BigNumber.from("86400"),
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
