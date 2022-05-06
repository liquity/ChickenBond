import { BigNumber } from "@ethersproject/bignumber";

export const targetAverageAgeSeconds = BigNumber.from("2592000");
export const initialAccrualParameter = BigNumber.from("2592000000000000000000000");
export const minimumAccrualParameter = BigNumber.from("2592000000000000000000");
export const accrualAdjustmentRate = BigNumber.from("10000000000000000");
export const accrualAdjustmentPeriodSeconds = BigNumber.from("86400");
export const chickenInAMMTax = BigNumber.from("10000000000000000");
