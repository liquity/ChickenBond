import { newtonRaphson } from "../utils/newton";

export interface CashFlow {
  value: number;
  time: number; // seconds since epoch
}

const xnpv =
  (period: number, [c0, ...cs]: CashFlow[]) =>
  (discountRate: number) =>
    cs.reduce((res, ci) => {
      const t = (ci.time - c0.time) / period;
      return res + ci.value / Math.pow(1 + discountRate, t);
    }, c0.value);

const xnpvPrime =
  (period: number, [c0, ...cs]: CashFlow[]) =>
  (discountRate: number) =>
    cs.reduce((res, ci) => {
      const t = (ci.time - c0.time) / period;
      return res - (t * ci.value) / Math.pow(1 + discountRate, t + 1);
    }, 0);

const pickValue = ({ value }: CashFlow) => value;
const add = (a: number, b: number) => a + b;

// assuming cashFlows ordered by time
const annualizedReturn = (period: number, cashFlows: CashFlow[]) => {
  const startTime = cashFlows[0].time;
  const endTime = cashFlows[cashFlows.length - 1].time;

  const values = cashFlows.map(pickValue);
  const endValue = values.reduce(add);
  const debit = -values.filter(x => x < 0).reduce(add);

  return Math.pow(1 + endValue / debit, period / (endTime - startTime)) - 1;
};

export const xirr = (
  period: number,
  cashFlows: CashFlow[],
  guess = annualizedReturn(period, cashFlows)
): number | null =>
  newtonRaphson({
    f: xnpv(period, cashFlows),
    fPrime: xnpvPrime(period, cashFlows),
    x0: guess
  });
