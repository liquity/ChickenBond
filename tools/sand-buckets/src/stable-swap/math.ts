import assert from "assert";

import {
  approxPositive,
  binSearchDesc,
  clamped,
  converge,
  flow2,
  flow3,
  mapMul,
  nonNegative,
  prod,
  sum,
  zipAdd,
  zipSub
} from "../utils";

export interface StableSwapConstants {
  n: number;
  nn: number;
  Ann: number;
}

export interface StableSwapConstantsWithFee extends StableSwapConstants {
  fee: number;
  adminFee: number;
  baseFee: number;
}

const assertNonNegative = (x: number): number => {
  assert(x >= 0);
  return x;
};

// See https://atulagarwal.dev/posts/curveamm/stableswap/ for an explanation of the formula
export const D =
  ({ n, nn, Ann }: Readonly<StableSwapConstants>) =>
  (X: number[]) => {
    assert(X.every(nonNegative));

    const S = sum(X);
    const P = prod(X);

    // XXX approxEq?
    if (S === 0) {
      return 0;
    }

    return assertNonNegative(
      converge(S, D => {
        const D_P = D ** (n + 1) / (nn * P);
        return ((Ann * S + D_P * n) * D) / ((Ann - 1) * D + (n + 1) * D_P);
      })
    );
  };

// See https://atulagarwal.dev/posts/curveamm/stableswap/ for an explanation of the formula
export const y_D =
  ({ n, nn, Ann }: Readonly<StableSwapConstants>) =>
  (i: number, D: number, X: number[]) => {
    assert(X.every(nonNegative));

    const X_ = X.filter((_, j) => j !== i);
    const S_ = sum(X_);
    const P_ = prod(X_);
    const b = S_ + D / Ann;
    const c = D ** (n + 1) / (nn * P_ * Ann);

    return assertNonNegative(converge(D, y => (y * y + c) / (2 * y + b - D)));
  };

export const constants = (n: number, A: number): StableSwapConstants => ({
  n,
  nn: n ** n,
  // See https://github.com/asquare08/AMM-Models/blob/main/Curve%20AMM%20plots.ipynb for the
  // difference between Ann = A vs. (A * n) vs. (A * n ** n)
  // Curve uses A * n
  // (See https://github.com/curvefi/curve-contract/blob/b0bbf77f8f93c9c5f4e415bce9cd71f0cdee960e/contracts/pools/3pool/StableSwap3Pool.vy#L204)
  Ann: A * n
});

const constants2 = (constantsOrA: number | Readonly<StableSwapConstants>): StableSwapConstants =>
  typeof constantsOrA === "number" ? constants(2, constantsOrA) : constantsOrA;

const y2 =
  (constantsOrA: number | Readonly<StableSwapConstants>, D: number) =>
  (x: number): number =>
    y_D(constants2(constantsOrA))(1, D, [x, 0]);

const dydxYFromXY =
  (D_Ann: number) =>
  (x: number, y: number): [dydx: number, y: number] => {
    return [(x * y + D_Ann / x) / (x * y + D_Ann / y), y];
  };

// (D / Ann) * (D / n) ** n;
const D_Ann = ({ n, nn, Ann }: Readonly<StableSwapConstants>, D: number) =>
  D ** (n + 1) / (Ann * nn);

// For a 2-pool with amplification A, invariant D and balance on one side x,
// finds the spot price dy/dx and the other side's balance y.
export const dydxYFromX = (constantsOrA: number | Readonly<StableSwapConstants>, D: number) => {
  const c = constants2(constantsOrA);
  const y = y2(c, D);
  const f = dydxYFromXY(D_Ann(c, D));

  return (x: number) => f(x, y(x));
};

// There must be a better way to do this...
export const xyFromDydx: (A: number, D: number) => (dydx: number) => [x: number, y: number] = (
  A,
  D
) => binSearchDesc(0, D / 2)(dydxYFromX(A, D));

// export const xyFromDydx = (A: number, D: number) => {
//   const c = constants2(A);
//   const d = D_Ann(c, D);
//   const dydxY = dydxYFromX(c, D);

//   return (targetDydx: number): [x: number, y: number] => {
//     const x = converge(D / 2, x => {
//       const [dydx, y] = dydxY(x);
//       const d2ydx2 = (2 * d * (-dydx * (-dydx / y + 1 / x) + y / (x * x))) / (x * y * y + d);

//       return x - (targetDydx - dydx) / d2ydx2;
//     });

//     const [, y] = dydxY(x);
//     return [x, y];
//   };
// };

export const dxThatSetsYOverX =
  (targetYOverX: number) =>
  ({ fee, adminFee, ...constants }: Readonly<StableSwapConstantsWithFee>) => {
    const r = fee * (1 - adminFee);
    const r1 = 1 - r;

    return (x: number, y: number): number => {
      assert(targetYOverX * x <= y);

      const ry = r * y;
      const D0 = D(constants)([x, y]);
      const f = dydxYFromX(constants, D0);

      const x_ = converge(D0, x_ => {
        const [dydx, y_] = f(x_);
        return x_ - (r1 * y_ + ry - targetYOverX * x_) / (r1 * -dydx - targetYOverX);
      });

      const dx = x_ - x;
      assert(approxPositive(dx));

      return clamped(dx);
    };
  };

export const balancingDx = dxThatSetsYOverX(1);

export const dxThatSplitsPool = (targetXOverXPlusY: number) =>
  dxThatSetsYOverX((1 - targetXOverXPlusY) / targetXOverXPlusY);

const xyAfterDeposit =
  ({ baseFee, adminFee, ...constants }: Readonly<StableSwapConstantsWithFee>) =>
  (xy: [x: number, y: number]) => {
    const D0 = D(constants)(xy);

    return (d: [dx: number, dy: number]) => {
      const xy1 = zipAdd(xy, d);
      const D1 = D(constants)(xy1);
      const ideal = mapMul(xy, D1 / D0);
      const diff = zipSub(xy1, ideal).map(Math.abs);
      const fee = mapMul(diff, baseFee * adminFee);

      return zipSub(xy1, fee) as [x: number, y: number];
    };
  };

const dx0 = (dx: number): [dx: number, dy: number] => [dx, 0];

export const oneCoinDepositThatSetsYOverX =
  (targetYOverX: number) =>
  (constants: Readonly<StableSwapConstantsWithFee>) =>
  (x: number, y: number) =>
    flow2(
      binSearchDesc(
        0,
        2 * (y / targetYOverX - x) // XXX
      )(flow3(dx0, xyAfterDeposit(constants)([x, y]), ([x, y]) => [y / x])),
      ([dx]) => dx
    )(targetYOverX);

export const balancingOneCoinDeposit = oneCoinDepositThatSetsYOverX(1);

const xAfterOneCoinWithdrawal =
  ({ baseFee, adminFee, ...constants }: Readonly<StableSwapConstantsWithFee>) =>
  ([x, y]: [x: number, y: number]) => {
    const D0 = D(constants)([x, y]);

    return (burnFraction: number): number => {
      const D1 = D0 * (1 - burnFraction);
      const x1 = y2(constants, D1)(y);

      const xr = x - baseFee * (x * (D1 / D0) - x1);
      const yr = y + baseFee * (y * (D1 / D0) - y);

      const dx = xr - y2(constants, D1)(yr);
      return x1 * adminFee + (x - dx) * (1 - adminFee);
    };
  };

export const oneCoinWithdrawalThatSetsYOverX =
  (targetYOverX: number) =>
  (constants: Readonly<StableSwapConstantsWithFee>) =>
  (x: number, y: number) =>
    flow2(
      binSearchDesc(0, 1)(flow2(xAfterOneCoinWithdrawal(constants)([x, y]), x2 => [x2 / y])),
      ([burnFraction]) => burnFraction
    )(1 / targetYOverX);

export const balancingOneCoinWithdrawal = oneCoinWithdrawalThatSetsYOverX(1);
