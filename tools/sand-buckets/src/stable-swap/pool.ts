import assert from "assert";

import { constants, D, StableSwapConstantsWithFee, y_D } from "./math";

import {
  approxPositive,
  check,
  clamped,
  mapMul,
  nonNegative,
  ones,
  positive,
  set,
  zeros,
  zipAdd,
  zipMul,
  zipSub
} from "../utils";

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
      this.balances[i] = balance;
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
    check(balancesAfterFees.every(positive), "impossible liquidity change");

    const D2 = this.D(balancesAfterFees);
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

  removeLiquidityImbalance(amounts: number[]): number {
    assert(amounts.every(nonNegative));
    const newBalances = zipSub(this.balances, amounts);

    const [burn, fees] = this.calcTokenAmountWithFees(newBalances);

    check(approxPositive(-burn), "impossible withdrawal");
    const clampedBurn = clamped(-burn);
    assert(clampedBurn <= this.totalSupply);

    this._storeBalances(zipSub(newBalances, mapMul(fees, this.adminFee)));
    this.totalSupply -= clampedBurn;

    return clampedBurn;
  }

  removeLiquidity(burn: number): number[] {
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
