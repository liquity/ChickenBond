import { BigNumber } from "@ethersproject/bignumber";
import { AddressZero } from "@ethersproject/constants";
import { Decimal } from "@liquity/lib-base";

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
  nftRandomnessDivisor: BigNumber;
  redemptionFeeBeta: BigNumber;
  redemptionFeeMinuteDecayFactor: BigNumber;
  bondNFTTransferLockoutPeriodSeconds: BigNumber;
  lusdFaucetTapAmount: BigNumber;
  lusdFaucetTapPeriod: BigNumber;
  harvesterBAMMAPR: BigNumber;
  harvesterCurveAPR: BigNumber;
  yearnGovernanceAddress: string;
}

const SPEED = 24; // Fake days per real day
const DAY = BigNumber.from(24 * 60 * 60).div(SPEED);
const ONE = BigNumber.from(10).pow(18);

// Half-life of 12h
const REDEMPTION_DECAY = Decimal.from(0.5 ** (1 / DAY.div(120).toNumber()));

export const defaultConfig: Readonly<LUSDChickenBondConfig> = {
  targetAverageAgeSeconds: DAY.mul(30),
  initialAccrualParameter: DAY.mul(5).mul(ONE),
  minimumAccrualParameter: DAY.mul(5).mul(ONE).div(1000),
  accrualAdjustmentRate: ONE.div(100),
  accrualAdjustmentPeriodSeconds: DAY,
  chickenInAMMFee: ONE.div(100),
  curveDepositDydxThreshold: ONE.sub(1),
  curveWithdrawalDxdyThreshold: ONE.add(1),
  bootstrapPeriodChickenIn: DAY.mul(7),
  bootstrapPeriodRedeem: DAY.mul(7),
  bootstrapPeriodShift: DAY.mul(90),
  shifterDelay: BigNumber.from(1),
  shifterWindow: BigNumber.from(600),
  minBLUSDSupply: ONE,
  minBondAmount: ONE.mul(100),
  nftRandomnessDivisor: ONE.mul(1000),
  redemptionFeeBeta: BigNumber.from(2),
  redemptionFeeMinuteDecayFactor: BigNumber.from(REDEMPTION_DECAY.hex),
  bondNFTTransferLockoutPeriodSeconds: DAY,
  lusdFaucetTapAmount: ONE.mul(10000),
  lusdFaucetTapPeriod: DAY,
  harvesterBAMMAPR: ONE.mul(SPEED).div(5),
  harvesterCurveAPR: ONE.mul(SPEED).div(20),
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
