import { addPair, addToken, box, calculateRatio, Pair, panic, subToken, ZEROES } from "../utils";
import { ChickenBond, ChickenBondCurve } from "./ChickenBond";

export type ChickenMove = "in" | "out" | "re";
export type ChickenState = "in" | "out" | "cooped";

export interface Chicken<T extends ChickenState = ChickenState> {
  state: T;
  bond: ChickenBond;
  phoenix?: Chicken<T>;
}

export interface ChickenFarmStats {
  coop: Pair;
  in: Pair;
  out: Pair;
  tollTOKEN: number;
}

export interface ChickenFarmDatum extends ChickenFarmStats {
  k: number;
  r: number;
  e: number;
  u: number;
  y: number;
  polRatio: number;
  premium: number;
}

const isCooped = (c: Chicken): c is Chicken<"cooped"> => c.state === "cooped";
const isIn = (c: Chicken): c is Chicken<"in"> => c.state === "in";
const isOut = (c: Chicken): c is Chicken<"out"> => c.state === "out";

const pickBond = (c: Chicken) => c.bond;

const statsFrom = (population: Chicken[], restIn: Pair): ChickenFarmStats => {
  const [coopBonds, inBonds, outBonds] = [isCooped, isIn, isOut].map(f =>
    population.filter(f).map(pickBond)
  );

  const tollTOKEN = inBonds.reduce((a, b) => a + b.tollTOKEN, 0);

  return {
    coop: coopBonds.reduce(addPair, ZEROES),
    in: subToken(inBonds.reduce(addPair, restIn), tollTOKEN),
    out: outBonds.reduce(addPair, ZEROES),
    tollTOKEN
  };
};

export interface ChickenFarmCommonParams {
  k: number;
  stats: ChickenFarmStats;
  polRatio: number;
  coop: Chicken<"cooped">[];
}

export interface ChickenFarmSteerParams extends ChickenFarmCommonParams {
  r: number;
  e: number;
  u: number;
  y: number;
}

export interface ChickenFarmMoveParams extends ChickenFarmSteerParams {
  bond: ChickenBond;
  dArr: number;
}

export interface ChickenFarmParams {
  period: number;
  u0: number;
  in0: Pair;

  curve: ChickenBondCurve;

  grow: (params: ChickenFarmCommonParams) => unknown;
  spot: (params: ChickenFarmCommonParams) => unknown;
  point: (params: ChickenFarmCommonParams) => unknown;
  gauge: (params: ChickenFarmCommonParams) => unknown;
  steer: (params: ChickenFarmSteerParams) => unknown;
  hatch: (params: ChickenFarmSteerParams) => unknown;
  move: (params: ChickenFarmMoveParams) => unknown;
}

const validateGrow = (x: unknown): [number, number] =>
  typeof x === "number"
    ? [x, x]
    : Array.isArray(x) && x.length === 2 && x.every(y => typeof y === "number")
    ? (x as [number, number])
    : panic("grow() must return a number");

const validatePoint = (x: unknown): number =>
  typeof x === "number" ? x : panic("point() must return a number");

const validateGauge = (x: unknown): number =>
  typeof x === "number" ? x : panic("gauge() must return a number");

// const validateSteer = (x: unknown): number =>
//   typeof x === "number"
//     ? x > 0
//       ? x
//       : panic("steer() must return positive")
//     : panic("steer() must return a number");

const validateSteer = (x: unknown): number =>
  typeof x === "number" ? x : panic("steer() must return a number");

const validateSpot = (x: unknown): number =>
  typeof x === "number"
    ? x > 0
      ? x
      : panic("spot() must return positive")
    : panic("spot() must return a number");

const validateHatch = (x: unknown): number =>
  typeof x === "number"
    ? x > 0
      ? x
      : panic("hatch() must return positive")
    : panic("hatch() must return a number or an array of numbers");

const validateMove = (x: unknown): ChickenMove =>
  x === "in" || x === "out" || x === "re" ? x : panic("move() must return either 'in' or 'out'");

const roi = (c: number, lambda: number) => c * lambda - 1;

const arr = (bond: { c: number; dk: number }, lambda: number, period: number) =>
  (1 + roi(bond.c, lambda)) ** (period / bond.dk) - 1;

export class ChickenFarm {
  readonly params: Readonly<ChickenFarmParams>;
  readonly population: Chicken[] = [];

  private _k = 0;
  private _u: number;
  private _restIn: Pair;
  private _stats: ChickenFarmStats;
  private _phoenices: Chicken[] = [];

  constructor(params: Readonly<ChickenFarmParams>) {
    this.params = params;

    this._u = params.u0;
    this._restIn = params.in0;
    this._stats = statsFrom(this.population, this._restIn);
  }

  farm(): ChickenFarmDatum {
    const k = this._k;
    const stats = this._stats;
    const polRatio = calculateRatio(stats.in);
    const coop = this.population.filter(isCooped);

    const commonParams = { k, stats, polRatio, coop };

    const grow = validateGrow(this.params.grow(commonParams));
    const [coopInYield, tollYield] = grow.map(apy => (1 + apy) ** (1 / this.params.period) - 1);
    const harvest = (stats.coop.TOKEN + stats.in.TOKEN) * coopInYield + stats.tollTOKEN * tollYield;

    const marketPrice = validateSpot(this.params.spot(commonParams));
    const lambda = marketPrice / polRatio;
    const premium = marketPrice - polRatio;

    const u = this._u;
    const r = validatePoint(this.params.point(commonParams));
    const y = validateGauge(this.params.gauge(commonParams));
    const e = r - y;

    const steerParams = { ...commonParams, r, e, u, y };

    const uNext = validateSteer(this.params.steer(steerParams));

    this.population.push(
      ...this._phoenices.map<Chicken>(phoenix => ({
        state: "cooped",
        bond: new ChickenBond(this.params.curve, k, marketPrice * phoenix.bond.sTOKEN),
        phoenix
      })),

      ...box(this.params.hatch(steerParams)).map<Chicken>(x => ({
        state: "cooped",
        bond: new ChickenBond(this.params.curve, k, validateHatch(x))
      }))
    );

    this._phoenices = [];

    this.population.forEach(chicken => {
      if (chicken.state === "cooped") {
        const curr = chicken.bond._poke(k, u, polRatio);
        const next = chicken.bond.peek(k + 1, u, polRatio);

        const currArr = arr(curr, lambda, this.params.period);
        const nextArr = arr(next, lambda, this.params.period);
        const dArr = nextArr - currArr;

        const retMove = this.params.move({ ...steerParams, bond: chicken.bond, dArr });

        if (retMove != null) {
          const move = validateMove(retMove);

          if (move === "re") {
            this._phoenices.push(chicken);
            chicken.state = "in";
          } else {
            chicken.state = move;
          }
        }
      }
    });

    this._k = k + 1;
    this._u = uNext;
    this._restIn = addToken(this._restIn, harvest);
    this._stats = statsFrom(this.population, this._restIn);

    return { k, r, e, u, y, polRatio, premium, ...stats };
  }
}
