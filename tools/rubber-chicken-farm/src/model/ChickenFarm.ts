import { addPair, addToken, box, calculateRatio, Pair, panic, subToken, ZEROES } from "../utils";
import { ChickenBond, ChickenBondCurve } from "./ChickenBond";

export type ChickenMove = "in" | "out";
export type ChickenState = ChickenMove | "cooped";

export interface Chicken<T extends ChickenState = ChickenState> {
  state: T;
  bond: ChickenBond;
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
  coop: Chicken<"cooped">[];
}

export interface ChickenFarmSteerParams extends ChickenFarmCommonParams {
  r: number;
  e: number;
  u: number;
  y: number;
  premium: number;
}

export interface ChickenFarmMoveParams extends ChickenFarmSteerParams {
  bond: ChickenBond;
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

const validateGrow = (x: unknown): number =>
  typeof x === "number" ? x : panic("grow() must return a number");

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
  x === "in" || x === "out" ? x : panic("move() must return either 'in' or 'out'");

export class ChickenFarm {
  readonly params: Readonly<ChickenFarmParams>;
  readonly population: Chicken[] = [];

  private _k = 0;
  private _u: number;
  private _restIn: Pair;
  private _stats: ChickenFarmStats;

  constructor(params: Readonly<ChickenFarmParams>) {
    this.params = params;

    this._u = params.u0;
    this._restIn = params.in0;
    this._stats = statsFrom(this.population, this._restIn);
  }

  farm(): ChickenFarmDatum {
    const k = this._k;
    const stats = this._stats;
    const coop = this.population.filter(isCooped);

    const commonParams = { k, stats, coop };

    const grow = validateGrow(this.params.grow(commonParams));
    const yieldPerStep = (1 + grow) ** (1 / this.params.period) - 1;
    const harvest = (stats.coop.TOKEN + stats.in.TOKEN) * yieldPerStep;

    const spot = validateSpot(this.params.spot(commonParams));
    const polRatio = calculateRatio(stats.in);
    const premium = spot / polRatio - 1;

    const u = this._u;
    const r = validatePoint(this.params.point(commonParams));
    const y = validateGauge(this.params.gauge(commonParams));
    const e = r - y;

    const steerParams = { ...commonParams, r, e, u, y, premium };

    const uNext = validateSteer(this.params.steer(steerParams));

    this.population.push(
      ...box(this.params.hatch(steerParams)).map<Chicken>(x => ({
        state: "cooped",
        bond: new ChickenBond(this.params.curve, k, validateHatch(x))
      }))
    );

    this.population.forEach(chicken => {
      if (chicken.state === "cooped") {
        chicken.bond._poke(k, u, polRatio);

        const retMove = this.params.move({ ...steerParams, bond: chicken.bond });
        if (retMove != null) {
          chicken.state = validateMove(retMove);
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
