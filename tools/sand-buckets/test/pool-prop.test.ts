import { testProp, fc } from "ava-fast-check";

import { mapMul, nonZero, zipDiv, zipSub } from "../src/utils";

import {
  balancingDx,
  balancingOneCoinDeposit,
  balancingOneCoinWithdrawal,
  dxThatSetsYOverX,
  dydxYFromX,
  oneCoinDepositThatSetsYOverX,
  oneCoinWithdrawalThatSetsYOverX,
  StableSwapPool,
  StableSwapPoolParams,
  xyFromDydx
} from "../src/pool";

const EPSILON = 1e-6;
const ROUGH_EPSILON = 1e-4;

const approxEq = (a: number, b: number) => Math.abs(a - b) < EPSILON;
const roughApproxEq = (a: number, b: number) => Math.abs(a - b) < ROUGH_EPSILON;
const approxZero = (x: number) => approxEq(x, 0);
const approxGt = (a: number, b: number) => a > b - EPSILON;

const orderedPair = ([a, b]: [number, number]): [number, number] => (a <= b ? [a, b] : [b, a]);

const balance = () => fc.float({ min: 0.001 }); // ratio between any 2 coins > 1:1000
const balances = () => fc.array(balance(), { minLength: 2, maxLength: 4 }); // 2-4 coins

interface FloatConstraints {
  min?: number;
  max?: number;
}

interface PoolParamsConstraints {
  A?: FloatConstraints;
  fee?: FloatConstraints;
  adminFee?: FloatConstraints;
}

const poolParams =
  ({ A = { max: 5000 }, fee = {}, adminFee = {} }: PoolParamsConstraints = {}) =>
  (balances: number[]) =>
    fc.record({
      n: fc.constant(balances.length),
      A: fc.float(A).filter(nonZero), // avoid division by zero
      fee: fc.float(fee),
      adminFee: fc.float(adminFee),
      balances: fc.constant(balances)
    });

interface PoolParamsConstraintsWithPriceRange extends PoolParamsConstraints {
  dydx: Required<FloatConstraints>;
}

const poolParamsInPriceRange = ({
  dydx,
  A = { max: 5000 },
  fee = {},
  adminFee = {}
}: PoolParamsConstraintsWithPriceRange) =>
  fc
    .record({
      dydx: fc.float(dydx),
      n: fc.constant(2),
      A: fc.float(A).filter(nonZero),
      fee: fc.float(fee),
      adminFee: fc.float(adminFee)
    })
    .map(({ dydx, ...params }) => ({
      ...params,
      balances: xyFromDydx(params.A, 2)(dydx)
    }));

testProp(
  "Exchange homogeneity",
  [balances().chain(poolParams()), fc.float().filter(nonZero), fc.float({ min: 1, max: 10 })],
  (t, { balances, ...params }, x, s) => {
    const p1 = new StableSwapPool({ balances, ...params });
    const p2 = new StableSwapPool({ balances: mapMul(balances, s), ...params });

    const dy1 = p1.exchange(0, 1, x);
    const dy2 = p2.exchange(0, 1, x * s);

    t.true(approxEq(dy1 * s, dy2));
    t.true(zipSub(mapMul(p1.balances, s), p2.balances).every(approxZero));
  }
  // { numRuns: 1000000 }
);

const wontThrow = (msgPattern: string | RegExp) => (f: () => void) => {
  try {
    f();
    return true;
  } catch (error) {
    if (error instanceof Error && error.message.match(msgPattern)) {
      return false;
    }

    // Let other errors through
    return true;
  }
};

// When depositing in a different ratio than the pool's current balances, certain combination of
// amounts won't work, because they would either decrease the invariant "D" of the pool or turn
// some coin balance negative after the deduction of fees.
const canDepositInto = (params: StableSwapPoolParams) => (amount: number[]) =>
  wontThrow(/impossible (deposit|liquidity change)/i)(() =>
    new StableSwapPool(params).addLiquidity(amount)
  );

testProp(
  "Deposit homogeneity",
  [
    balances()
      .chain(poolParams())
      .chain(params =>
        fc.tuple(
          fc.constant(params),
          fc
            .array(fc.float(), { minLength: params.n, maxLength: params.n })
            .filter(canDepositInto(params))
        )
      ),
    fc.float({ min: 1, max: 10 })
  ],
  (t, [{ balances, ...params }, amounts], s) => {
    const p1 = new StableSwapPool({ balances, ...params });
    const p2 = new StableSwapPool({ balances: mapMul(balances, s), ...params });

    const lp1 = p1.addLiquidity(amounts);
    const lp2 = p2.addLiquidity(mapMul(amounts, s));

    t.true(approxEq(lp1 * p1.virtualPrice * s, lp2 * p2.virtualPrice));
    t.true(zipSub(mapMul(p1.balances, s), p2.balances).every(approxZero));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Proportional deposits have no fee",
  [
    balances().chain(poolParams()),
    fc.float({
      // fraction of existing balances to deposit
      min: 0.001, // avoid division by 0
      max: 10
    })
  ],
  (t, params, x) => {
    const p = new StableSwapPool(params);
    const newBalances = mapMul(p.balances, 1 + x);
    const depositAmounts = zipSub(newBalances, p.balances);
    const [, fees] = p.calcTokenAmountWithFees(newBalances);

    t.true(zipDiv(fees, depositAmounts).every(approxZero));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Proportional deposit followed by immediate withdrawal is lossless",
  [
    balances().chain(poolParams()),
    fc.float({
      // fraction of existing balances to deposit
      min: 0.001, // avoid division by 0
      max: 10
    })
  ],
  (t, params, x) => {
    const p = new StableSwapPool(params);
    const depositedAmounts = mapMul(p.balances, x);
    const lp = p.addLiquidity(depositedAmounts);
    const withdrawnAmounts = p.removeLiquidity(lp);

    t.true(zipSub(depositedAmounts, withdrawnAmounts).every(approxZero));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given a 2-pool, exchange(0, 1, dx) adds exactly dx to the left side of the pool",
  [fc.tuple(balance(), balance()).chain(poolParams()), fc.float()],
  (t, params, dx) => {
    const p = new StableSwapPool(params);
    const [x] = p.balances;
    p.exchange(0, 1, dx);
    const [x2] = p.balances;

    t.true(approxEq(x2, x + dx));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given a 2-pool [x, y] where x <= y, exchange(0, 1, y - x) leaves [y, x + (y - x) * fee * (1 - adminFee)]",
  [fc.tuple(balance(), balance()).map(orderedPair).chain(poolParams())],
  (t, params) => {
    const p = new StableSwapPool(params);
    const [x, y] = p.balances;
    p.exchange(0, 1, y - x);

    t.true(approxEq(p.balances[0], y));
    t.true(approxEq(p.balances[1], x + (y - x) * p.fee * (1 - p.adminFee)));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given a 2-pool [x, y] where x <= y, we can find the dx that reduces y / x to a target ratio",
  [
    fc
      .tuple(balance(), balance())
      .map(orderedPair)
      .chain(poolParams())
      .chain(params =>
        fc.tuple(
          fc.constant(params),
          fc.float({ max: params.balances[1] / params.balances[0] }).filter(nonZero)
        )
      )
  ],
  (t, [params, targetYOverX]) => {
    const p = new StableSwapPool(params);
    const [x, y] = p.balances;
    p.exchange(0, 1, dxThatSetsYOverX(targetYOverX)(p)(x, y));
    const [x2, y2] = p.balances;

    t.true(approxEq(x2 * targetYOverX, y2));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given a 2-pool [x, y] where x <= y, we can find dx such that exchange(0, 1, dx) balances the pool",
  [fc.tuple(balance(), balance()).map(orderedPair).chain(poolParams())],
  (t, params) => {
    const p = new StableSwapPool(params);
    const [x, y] = p.balances;
    p.exchange(0, 1, balancingDx(p)(x, y));
    const [x2, y2] = p.balances;

    t.true(approxEq(x2, y2));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given a 2-pool [x, y] where x <= y, we can find dx such that addLiquidity([dx, 0]) balances the pool",
  [poolParamsInPriceRange({ dydx: { min: 1, max: 2 } })],
  (t, params) => {
    const p = new StableSwapPool(params);
    const [x, y] = p.balances;
    p.addLiquidity([balancingOneCoinDeposit(p)(x, y), 0]);
    const [x2, y2] = p.balances;

    t.true(approxEq(x2, y2));
  }
  // { numRuns: 500000 }
);

testProp(
  "Given a 2-pool [x, y] where x <= y, we can find lp such that removeLiquidityOneCoin(lp, 1) balances the pool",
  [poolParamsInPriceRange({ dydx: { min: 1, max: 2 } })],
  (t, params) => {
    const p = new StableSwapPool(params);
    const [x, y] = p.balances;
    p.removeLiquidityOneCoin(p.totalSupply * balancingOneCoinWithdrawal(p)(y, x), 1);
    const [x2, y2] = p.balances;

    t.true(approxEq(x2, y2));
  }
  // { numRuns: 500000 }
);

testProp(
  "Splitting up a swap is better for the swapper and worse for the pool",
  [fc.tuple(balance(), balance()).chain(poolParams()), fc.float(), fc.float()],
  (t, params, dx1, dx2) => {
    const pSplit = new StableSwapPool(params);
    const dySplit = pSplit.exchange(0, 1, dx1) + pSplit.exchange(0, 1, dx2);

    const pWhole = new StableSwapPool(params);
    const dyWhole = pWhole.exchange(0, 1, dx1 + dx2);

    t.true(approxGt(dySplit, dyWhole));
    t.true(approxEq(pWhole.balances[0], pSplit.balances[0]));
    t.true(approxGt(pWhole.balances[1], pSplit.balances[1]));
  }
  // { numRuns: 1000000 }
);

testProp(
  "Given A, D and dydx, we can find the 2-pool having spot price dydx",
  [
    fc.float({ max: 5000 }).filter(nonZero),
    fc.float({ min: 2, max: 10 }),
    fc.float({ min: 1, max: 2 })
  ],
  (t, A, D, dydx) => {
    const [x, y] = xyFromDydx(A, D)(dydx);
    const [dydxReapplied] = dydxYFromX(A, D)(x);
    const p = new StableSwapPool({ n: 2, A, fee: 0, adminFee: 0, balances: [x, y] });
    const dx = p.balances[0] * 1e-6;
    const [dy] = p.dy(0, 1, dx);

    t.true(approxEq(dydx, dydxReapplied));
    t.true(roughApproxEq(dydx, dy / dx));
  }
  // { numRuns: 1000000 }
);

testProp(
  "When price < 2.0, fee of single-sided deposit into light side is capped at the swap fee",
  [
    poolParamsInPriceRange({ dydx: { min: 1, max: 2 } }).chain(params => {
      const p = new StableSwapPool(params);
      const [x, y] = p.balances;

      return fc.tuple(
        fc.constant(params),
        // don't imbalance the pool in the other direction
        fc.float({ max: balancingOneCoinDeposit(p)(x, y) })
      );
    })
  ],
  (t, [params, x]) => {
    const p = new StableSwapPool(params);
    const lp = p.addLiquidity([x, 0]);

    t.true(approxGt(lp * p.virtualPrice, x * (1 - p.fee)));
  }
  // { numRuns: 500000 }
);

testProp(
  "When price > 0.5, fee of single-sided withdrawal from heavy side is capped at the swap fee",
  [
    // we will use the other side of the pool, which will have price > 1/2 = 0.5
    poolParamsInPriceRange({ dydx: { min: 1, max: 2 } }).chain(params => {
      const p = new StableSwapPool(params);
      const [x, y] = p.balances;

      return fc.tuple(
        fc.constant(params),
        // don't imbalance the pool in the other direction
        fc.float({ max: p.totalSupply * balancingOneCoinWithdrawal(p)(y, x) })
      );
    })
  ],
  (t, [params, lp]) => {
    const p = new StableSwapPool(params);
    const initialValue = lp * p.virtualPrice;
    const dy = p.removeLiquidityOneCoin(lp, 1);

    t.true(approxGt(dy, initialValue * (1 - p.fee)));
  }
  // { numRuns: 500000 }
);

const yOverX = ([x, y]: number[]) => y / x;

// // "Worst case" version that minimizes pool revenue
// const reduceRatio = (p: StableSwapPool, targetYOverX: number) => {
//   const [x, y] = p.balances;
//   const dx = findDxThatSetsYOverX(targetYOverX)(p)(x, y) / 1000;

//   while (yOverX(p.balances) > targetYOverX) {
//     p.exchange(0, 1, dx);
//   }
// };

const reduceRatio = (p: StableSwapPool, targetYOverX: number) => {
  const [x, y] = p.balances;
  const dx = dxThatSetsYOverX(targetYOverX)(p)(x, y);
  p.exchange(0, 1, dx);
};

const notEqualPair = ([a, b]: [number, number]) => !approxEq(a, b);

testProp(
  // Only testing for 0.04% fee and 0.5% admin fee, which are the immutable parameters of the
  // LUSD-3CRV pool.
  // At very large values (which are unrealistic) the property starts to break down.
  // Technically, we're testing withdrawals in the range "price < 1 / (1 - fee)", but at low
  // percentages, this doesn't make a big difference.
  "Depositing while price > (1 + fee) and withdrawing while price < (1 - fee) is profitable",
  [
    fc
      .record({
        n: fc.constant(2),
        A: fc.float({ max: 5000 }).filter(nonZero),
        fee: fc.constant(0.0004),
        adminFee: fc.constant(0.5)
      })
      .map(params => ({
        params,
        yOverXMinPrice: yOverX(xyFromDydx(params.A, 2)(1 + params.fee)),
        yOverXMaxPrice: yOverX(xyFromDydx(params.A, 2)(2))
      }))
      .chain(({ params, yOverXMinPrice, yOverXMaxPrice }) => {
        const range = { min: yOverXMinPrice, max: yOverXMaxPrice };

        return fc.tuple(
          fc.constant(params),
          fc.tuple(fc.float(range), fc.float(range)).filter(notEqualPair).map(orderedPair),
          fc.tuple(fc.float(range), fc.float(range)).filter(notEqualPair).map(orderedPair)
        );
      })
  ],
  (t, [params, [improvedYOverX, initialYOverX], [improvedXOverY, flippedXOverY]]) => {
    const [x, y] = [1, initialYOverX];
    const p = new StableSwapPool({ ...params, balances: [x, y] });
    const dx = oneCoinDepositThatSetsYOverX(improvedYOverX)(p)(x, y);
    const mint = p.addLiquidity([dx, 0]);

    reduceRatio(p, 1 / flippedXOverY); // make the pool left-heavy

    const [x2, y2] = p.balances;
    const burn = oneCoinWithdrawalThatSetsYOverX(1 / improvedXOverY)(p)(x2, y2);
    const dx2 = p.removeLiquidityOneCoin(burn, 0);

    t.true(approxGt(dx2 / burn, dx / mint));
  }
  // { numRuns: 500000 }
);
