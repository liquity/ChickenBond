import assert from "assert";

const MAX_ITERATIONS = 256;
const EPSILON = 1e-6;

export const approxEq =
  (epsilon = EPSILON) =>
  (a: number, b: number) =>
    Math.abs(a - b) < epsilon;

const add = (a: number, b: number) => a + b;
const sub = (a: number, b: number) => a - b;
const mul = (a: number, b: number) => a * b;

const sum = (x: number[]) => x.reduce(add, 0);
const prod = (x: number[]) => x.reduce(mul, 1);

const zeros = (n: number) => new Array<number>(n).fill(0);
const ones = (n: number) => new Array<number>(n).fill(1);

const set = <T>(arr: T[], i: number, newValue: T) =>
  arr.map((oldValue, k) => (k === i ? newValue : oldValue));

// const mapAdd = <T>(as: number[], b: number) => as.map(a => a + b);
// const mapSub = <T>(as: number[], b: number) => as.map(a => a - b);
const mapMul = <T>(as: number[], b: number) => as.map(a => a * b);

const zipWith =
  <T, U, V>(f: (t: T, u: U) => V) =>
  (ts: T[], us: U[]) =>
    ts.map((t, i) => f(t, us[i]));

const zipAdd = zipWith(add);
const zipSub = zipWith(sub);
const zipMul = zipWith(mul);

const iterate =
  <T>(found: (curr: T, prev: T) => boolean, maxIterations = MAX_ITERATIONS) =>
  (first: T, getNext: (prev: T) => T): T => {
    let prev = first;

    for (let i = 0; i < maxIterations; i++) {
      const curr = getNext(prev);

      if (found(curr, prev)) {
        return curr;
      }

      prev = curr;
    }

    throw new Error(`not found within ${maxIterations} iterations`);
  };

const converge = iterate(approxEq());

export interface StableSwapConstants {
  n: number;
  nn: number;
  Ann: number;
}

// See https://atulagarwal.dev/posts/curveamm/stableswap/ for an explanation of the formula
export const D =
  ({ n, nn, Ann }: Readonly<StableSwapConstants>) =>
  (X: number[]) => {
    const S = sum(X);
    const P = prod(X);

    // XXX approxEq?
    if (S === 0) {
      return 0;
    }

    return converge(S, D => {
      const D_P = D ** (n + 1) / (nn * P);
      return ((Ann * S + D_P * n) * D) / ((Ann - 1) * D + (n + 1) * D_P);
    });
  };

// See https://atulagarwal.dev/posts/curveamm/stableswap/ for an explanation of the formula
export const y_D =
  ({ n, nn, Ann }: Readonly<StableSwapConstants>) =>
  (i: number, D: number, X: number[]) => {
    const X_ = X.filter((_, j) => j !== i);
    const S_ = sum(X_);
    const P_ = prod(X_);
    const b = S_ + D / Ann;
    const c = D ** (n + 1) / (nn * P_ * Ann);

    return converge(D, y => (y * y + c) / (2 * y + b - D));
  };

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
  extends StableSwapConstants,
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
    const {
      n,
      A,
      fee = 0,
      adminFee = 0,
      balances = zeros(n),
      rates = ones(n),
      totalSupply
    } = params;

    assert(balances.length === n);
    assert(rates.length === n);

    const nn = n ** n;
    // See https://github.com/curvefi/curve-contract/blob/b0bbf77f8f93c9c5f4e415bce9cd71f0cdee960e/contracts/pools/3pool/StableSwap3Pool.vy#L204
    const Ann = A * n; // XXX Huh, shouldn't this be A * n**n?

    this.n = n;
    this.A = A;
    this.nn = nn;
    this.Ann = Ann;
    this.fee = fee;
    this.adminFee = adminFee;
    this.baseFee = (fee * n) / (4 * (n - 1));
    this.balances = balances;
    this._rates = rates;

    this.totalSupply = totalSupply ?? D({ n, nn, Ann })(zipMul(balances, rates));
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
      this.balances[i] = balance;
    });
  }

  calcTokenAmount(amounts: number[], isDeposit: boolean): number {
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

    const D2 = this.D(zipSub(newBalances, fees));
    const mintBurn = this.totalSupply * (D2 / D0 - 1);

    return [mintBurn, fees];
  }

  addLiquidity(amounts: number[]): number {
    const newBalances = zipAdd(this.balances, amounts);

    if (this.totalSupply === 0) {
      assert(amounts.every(amount => amount > 0));
      this._storeBalances(newBalances);
      return (this.totalSupply = this.D());
    }

    const [mint, fees] = this.calcTokenAmountWithFees(newBalances);
    this._storeBalances(zipSub(newBalances, mapMul(fees, this.adminFee)));
    this.totalSupply += mint;

    return mint;
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
