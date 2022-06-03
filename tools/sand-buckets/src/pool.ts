import assert from "assert";

const MAX_ITERATIONS = 256;
const EPSILON = 1e-7;

export const approxEq =
  (epsilon = EPSILON) =>
  (a: number, b: number) =>
    Math.abs(a - b) < epsilon;

const add = (a: number, b: number) => a + b;
const mul = (a: number, b: number) => a * b;

const sum = (x: number[]) => x.reduce(add, 0);
const prod = (x: number[]) => x.reduce(mul, 1);

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

const set = <T>(arr: T[], i: number, newValue: T) =>
  arr.map((oldValue, k) => (k === i ? newValue : oldValue));

export interface StableSwapConstants {
  readonly n: number;
  readonly nn: number;
  readonly Ann: number;
}

// See https://atulagarwal.dev/posts/curveamm/stableswap/ for an explanation of the formula
export const D =
  ({ n, nn, Ann }: StableSwapConstants) =>
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
  ({ n, nn, Ann }: StableSwapConstants) =>
  (i: number, D: number, X: number[]) => {
    const X_ = X.filter((_, j) => j !== i);
    const S_ = sum(X_);
    const P_ = prod(X_);
    const b = S_ + D / Ann;
    const c = D ** (n + 1) / (nn * P_ * Ann);

    return converge(D, y => (y * y + c) / (2 * y + b - D));
  };

export class StableSwapPool implements StableSwapConstants {
  readonly nn;
  readonly Ann;
  readonly baseFee;

  totalSupply;

  constructor(
    readonly n: number,
    readonly fee: number,
    readonly adminFee: number,
    readonly A: number,
    readonly X: number[] = new Array(n).fill(0),
    totalSupply?: number
  ) {
    assert(X.length === n);

    this.nn = n ** n;
    // See https://github.com/curvefi/curve-contract/blob/b0bbf77f8f93c9c5f4e415bce9cd71f0cdee960e/contracts/pools/3pool/StableSwap3Pool.vy#L204
    this.Ann = A * n; // XXX Huh, shouldn't this be A * n**n?
    this.baseFee = (this.fee * n) / (4 * (n - 1));

    this.totalSupply = totalSupply ?? this.D();
  }

  D(X = this.X) {
    return D(this)(X);
  }

  y_D(i: number, D: number, X = this.X) {
    return y_D(this)(i, D, X);
  }

  y(i: number, j: number, x: number) {
    return this.y_D(j, this.D(), set(this.X, i, x));
  }

  dy(i: number, j: number, dx: number): [dy: number, dyFee: number] {
    const dyNoFee = this.X[j] - this.y(i, j, this.X[i] + dx);
    const dyFee = dyNoFee * this.fee;

    return [dyNoFee - dyFee, dyFee];
  }

  exchange(i: number, j: number, dx: number): number {
    const [dy, dyFee] = this.dy(i, j, dx);

    this.X[i] += dx;
    this.X[j] -= dy + dyFee * this.adminFee;

    return dy;
  }

  private _storeX(newX: number[]) {
    newX.forEach((x, i) => {
      this.X[i] = x;
    });
  }

  addLiquidity(amounts: number[]): number {
    if (this.totalSupply === 0) {
      assert(amounts.every(amount => amount > 0));
    }

    const newX = amounts.map((amount, i) => this.X[i] + amount);

    const D0 = this.D();
    const D1 = this.D(newX);
    assert(D1 > D0);

    if (this.totalSupply === 0) {
      // No fee on initial deposit
      this._storeX(newX);
      this.totalSupply = D1;
      return D1;
    }

    this.X.forEach((oldX, i) => {
      const ideal = oldX * (D1 / D0);
      const diff = Math.abs(newX[i] - ideal);
      const fee = this.baseFee * diff;

      this.X[i] = newX[i] - fee * this.adminFee;
      newX[i] -= fee;
    });

    const D2 = this.D(newX);
    const mint = this.totalSupply * (D2 / D0 - 1);
    this.totalSupply += mint;
    return mint;
  }

  calcTokenAmount(amounts: number[], isDeposit: boolean): number {
    const newX = amounts.map((amount, i) => this.X[i] + (isDeposit ? amount : -amount));

    const D0 = this.D();
    const D1 = this.D(newX);

    const mintBurn = this.totalSupply * (D1 / D0 - 1);
    return isDeposit ? mintBurn : -mintBurn;
  }

  calcWithdrawOneCoin(burn: number, i: number): [dy: number, dyFee: number] {
    const D0 = this.D();
    const D1 = D0 * (1 - burn / this.totalSupply);
    const newY = this.y_D(i, D1);

    const reducedX = this.X.map(
      (oldX, j) => oldX - this.baseFee * (j === i ? oldX * (D1 / D0) - newY : oldX * (1 - D1 / D0))
    );

    const dy = reducedX[i] - this.y_D(i, D1, reducedX);
    const dyNoFee = this.X[i] - newY;

    return [dy, dyNoFee - dy];
  }

  removeLiquidityOneCoin(burn: number, i: number): number {
    const [dy, dyFee] = this.calcWithdrawOneCoin(burn, i);
    this.X[i] -= dy + dyFee * this.adminFee;
    this.totalSupply -= burn;
    return dy;
  }

  getVirtualPrice(): number {
    return this.D() / this.totalSupply;
  }
}

// const p = new StableSwapPool(2, 0.0004, 0.5, 500, [10e6, 60e6]);
// console.log(p.totalSupply);
