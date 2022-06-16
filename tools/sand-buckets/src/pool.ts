import assert from "assert";

import {
  binSearchDesc,
  check,
  converge,
  flow2,
  flow3,
  mapMul,
  nonNegative,
  ones,
  positive,
  prod,
  set,
  sum,
  zeros,
  zipAdd,
  zipMul,
  zipSub
} from "./utils";

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
const D =
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
const y_D =
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

const constants = (n: number, A: number): StableSwapConstants => ({
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
) => binSearchDesc(0, D / 2, 1e-9)(dydxYFromX(A, D));

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
        2 * (y / targetYOverX - x), // XXX
        1e-9
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
      binSearchDesc(0, 1, 1e-9)(flow2(xAfterOneCoinWithdrawal(constants)([x, y]), x2 => [x2 / y])),
      ([burnFraction]) => burnFraction
    )(1 / targetYOverX);

export const balancingOneCoinWithdrawal = oneCoinWithdrawalThatSetsYOverX(1);

const approxPositive = (x: number) => x > -1e-9;
const clamped = (x: number) => Math.max(x, 0);

export interface StableSwapPoolParams {
  n: number;
  A: number;
  fee?: number;
  adminFee?: number;
  balances?: number[];
  rates?: number[];
  totalSupply?: number;
}

export interface StableSwapPoolProperties
  extends StableSwapConstantsWithFee,
    Required<StableSwapPoolParams> {}

export class StableSwapPool {
  totalSupply;

  readonly n;
  readonly A;
  readonly nn;
  readonly Ann;
  readonly fee;
  readonly adminFee;
  readonly baseFee;
  readonly balances;

  private readonly _rates;

  constructor(params: Readonly<StableSwapPoolParams>) {
    const { n, A, fee = 0, adminFee = 0 } = params;
    assert(n >= 2);
    assert(A !== 0);
    assert(0 <= fee && fee <= 1);
    assert(0 <= adminFee && adminFee <= 1);

    const balances = params.balances?.slice() ?? zeros(n);
    assert(balances.length === n);
    assert(balances.every(nonNegative));

    const rates = params.rates?.slice() ?? ones(n);
    assert(rates.length === n);
    assert(rates.every(nonNegative));

    const { nn, Ann } = constants(n, A);
    const totalSupply = params.totalSupply ?? D({ n, nn, Ann })(zipMul(balances, rates));
    assert(totalSupply >= 0);

    this.totalSupply = totalSupply;
    this.n = n;
    this.A = A;
    this.nn = nn;
    this.Ann = Ann;
    this.fee = fee;
    this.adminFee = adminFee;
    this.baseFee = (fee * n) / (4 * (n - 1));
    this.balances = balances;
    this._rates = rates;
  }

  clone() {
    return new StableSwapPool({
      A: this.A,
      n: this.n,
      fee: this.fee,
      adminFee: this.adminFee,
      balances: this.balances,
      rates: this._rates,
      totalSupply: this.totalSupply
    });
  }

  get rates() {
    return this._rates;
  }

  X(balances = this.balances) {
    return zipMul(balances, this.rates);
  }

  D(balances = this.balances) {
    return D(this)(this.X(balances));
  }

  y_D(i: number, D: number, balances = this.balances) {
    return y_D(this)(i, D, this.X(balances)) / this.rates[i];
  }

  y(i: number, j: number, x: number) {
    return this.y_D(j, this.D(), set(this.balances, i, x));
  }

  dy(i: number, j: number, dx: number): [dy: number, dyFee: number] {
    assert(dx >= 0);
    const dyNoFee = this.balances[j] - this.y(i, j, this.balances[i] + dx);
    const dyFee = dyNoFee * this.fee;

    return [dyNoFee - dyFee, dyFee];
  }

  exchange(i: number, j: number, dx: number): number {
    const [dy, dyFee] = this.dy(i, j, dx);

    this.balances[i] += dx;
    this.balances[j] -= dy + dyFee * this.adminFee;

    return dy;
  }

  private _storeBalances(newBalances: number[]) {
    newBalances.forEach((balance, i) => {
      assert(approxPositive(balance));
      this.balances[i] = clamped(balance);
    });
  }

  calcTokenAmount(amounts: number[], isDeposit: boolean): number {
    assert(amounts.every(nonNegative));
    const newBalances = (isDeposit ? zipAdd : zipSub)(this.balances, amounts);

    const D0 = this.D();
    const D1 = this.D(newBalances);
    const mintBurn = this.totalSupply * (D1 / D0 - 1);

    return isDeposit ? mintBurn : -mintBurn;
  }

  calcTokenAmountWithFees(newBalances: number[]): [mintBurn: number, fees: number[]] {
    const D0 = this.D();
    const D1 = this.D(newBalances);

    const fees = newBalances.map((newBalance, i) => {
      const idealBalance = this.balances[i] * (D1 / D0);
      return Math.abs(newBalance - idealBalance) * this.baseFee;
    });

    const balancesAfterFees = zipSub(newBalances, fees);
    check(balancesAfterFees.every(approxPositive), "impossible liquidity change");

    const D2 = this.D(balancesAfterFees.map(clamped));
    const mintBurn = this.totalSupply * (D2 / D0 - 1);

    return [mintBurn, fees];
  }

  addLiquidity(amounts: number[]): number {
    assert(amounts.every(nonNegative));
    const newBalances = zipAdd(this.balances, amounts);

    if (this.totalSupply === 0) {
      assert(amounts.every(positive));
      this._storeBalances(newBalances);
      return (this.totalSupply = this.D());
    }

    const [mint, fees] = this.calcTokenAmountWithFees(newBalances);

    check(approxPositive(mint), "impossible deposit");
    const clampedMint = clamped(mint);

    this._storeBalances(zipSub(newBalances, mapMul(fees, this.adminFee)));
    this.totalSupply += clampedMint;

    return clampedMint;
  }

  removeLiquidity(burn: number) {
    assert(burn <= this.totalSupply);

    const amounts = this.balances.map(balance => balance * (burn / this.totalSupply));
    this._storeBalances(zipSub(this.balances, amounts));
    this.totalSupply -= burn;

    return amounts;
  }

  calcWithdrawOneCoin(burn: number, i: number): [dy: number, dyFee: number] {
    const D0 = this.D();
    const D1 = D0 * (1 - burn / this.totalSupply);
    const newY = this.y_D(i, D1);

    const reducedBalances = this.balances.map(
      (oldBalance, j) =>
        oldBalance -
        this.baseFee * (j === i ? oldBalance * (D1 / D0) - newY : oldBalance * (1 - D1 / D0))
    );

    const dy = reducedBalances[i] - this.y_D(i, D1, reducedBalances);
    const dyNoFee = this.balances[i] - newY;

    return [dy, dyNoFee - dy];
  }

  removeLiquidityOneCoin(burn: number, i: number): number {
    const [dy, dyFee] = this.calcWithdrawOneCoin(burn, i);
    this.balances[i] -= dy + dyFee * this.adminFee;
    this.totalSupply -= burn;
    return dy;
  }

  get virtualPrice(): number {
    return this.D() / this.totalSupply;
  }
}

export interface StableSwapMetaPoolParams extends Omit<StableSwapPoolParams, "n" | "rates"> {
  basePool: StableSwapPool;
  rate0?: number;
}

export class StableSwapMetaPool extends StableSwapPool {
  readonly basePool;
  readonly rate0;

  constructor(params: StableSwapMetaPoolParams) {
    const { basePool, rate0 = 1, ...superParams } = params;
    super({ ...superParams, n: 2, rates: [rate0, basePool.virtualPrice] });

    this.basePool = basePool;
    this.rate0 = rate0;
  }

  clone() {
    return new StableSwapMetaPool({
      A: this.A,
      fee: this.fee,
      adminFee: this.adminFee,
      balances: this.balances,
      rate0: this.rate0,
      totalSupply: this.totalSupply,
      basePool: this.basePool.clone()
    });
  }

  get rates() {
    return [this.rate0, this.basePool.virtualPrice];
  }

  dyUnderlying(i: number, j: number, dx: number): number {
    assert(i !== j);

    if (i >= 1 && j >= 1) {
      // base -> base
      const [dy] = this.basePool.dy(i - 1, j - 1, dx);
      return dy;
    }

    if (i === 0) {
      // meta -> base
      const [lp] = this.dy(0, 1, dx);
      const [dy] = this.basePool.calcWithdrawOneCoin(lp, j - 1);
      return dy;
    } else {
      // base -> meta
      const baseAmounts = set(zeros(this.basePool.n), i - 1, dx);
      const lp = this.basePool.calcTokenAmount(baseAmounts, true);
      const [dy] = this.dy(1, 0, lp * (1 - this.basePool.fee / 2)); // approximation
      return dy;
    }
  }
}
