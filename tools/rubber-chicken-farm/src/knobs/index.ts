import { ChickenFarmParams, ChickenFarmSteerParams } from "../model/ChickenFarm";

const steerOptions = new Set(["asymmetric", "symmetric", "pid"] as const);

export type SteerOption = typeof steerOptions extends Set<infer T> ? T : never;

export const validateSteerOption = (value: string): SteerOption => {
  if (!(steerOptions as Set<string>).has(value)) {
    throw new Error(`Invalid SteerOption value "${value}"`);
  }

  return value as SteerOption;
};

export interface ParsedSimulationKnobs extends Omit<ChickenFarmParams, "period" | "steer"> {
  periods: number;

  selectedSteer: SteerOption;

  asymmetricAdjustmentRate: number;
  symmetricAdjustmentRate: number;

  pidKp: (params: ChickenFarmSteerParams) => number;
  pidKi: (params: ChickenFarmSteerParams) => number;
  pidKd: (params: ChickenFarmSteerParams) => number;
}

export type SimulationKnobs = { [P in keyof ParsedSimulationKnobs]: string };

export const simulationDefaults: SimulationKnobs = {
  periods: "4",
  u0: "8",
  in0: "[1, 1]",
  curve: "(dk, u) => dk / (dk + u)",

  grow: "() => 0.05",

  //   spot: `
  // ({ stats: s }) => (
  //   s.coop.TOKEN +
  //   s.in.TOKEN +
  //   s.tollTOKEN * 0.5
  // ) / s.in.sTOKEN`.trim(),

  spot: `
({ stats: s }) =>
  s.in.TOKEN / s.in.sTOKEN * (1 + (
    s.coop.TOKEN * (1.05 ** (120/365) - 1) +
    s.in.TOKEN   * (1.05 ** (120/365) - 1) +
    s.tollTOKEN  * (1.02 ** (120/365) - 1)
  ) / s.in.TOKEN) ** 2`.trim(),

  point: "() => 60",

  gauge: `
({ k, coop }) => coop
  .reduce(([num, den], { bond }) => [
    num + bond.TOKEN * (k - bond.k0),
    den + bond.TOKEN
  ], [0, 0])
  .reduce((num, den) => num / (den || 1))`.trim(),

  hatch: `
({ k }) => new Array(
  randomBinomial(10, 0.998 ** k)
).fill().map(() => 100 * random())`.trim(),

  move: `
({ dArr }) => dArr < 0
  ? (random() < 0.5 ? "re" : "in")
  : null`.trim(),

  selectedSteer: "asymmetric",

  asymmetricAdjustmentRate: "0.01",
  symmetricAdjustmentRate: "0.01",

  pidKp: "() => 1",
  pidKi: "() => 0",
  pidKd: "() => 0"
};

export const parseSimulationKnobs = (knobs: Readonly<SimulationKnobs>): ParsedSimulationKnobs => {
  const { periods, u0, in0, selectedSteer, asymmetricAdjustmentRate, ...functions } = knobs;

  // eslint-disable-next-line no-new-func
  const [in0_TOKEN, in0_sTOKEN] = new Function(`"use strict"; return ${in0};`)();

  const parsedFunctions = Object.fromEntries(
    Object.entries(functions).map(([name, source]) => [
      name,
      // eslint-disable-next-line no-new-func
      new Function(`"use strict"; return ${source};`)()
    ])
  );

  return {
    in0: {
      TOKEN: in0_TOKEN,
      sTOKEN: in0_sTOKEN
    },

    periods: Number(periods),
    u0: Number(u0),
    asymmetricAdjustmentRate: Number(asymmetricAdjustmentRate),
    selectedSteer: validateSteerOption(selectedSteer),

    ...parsedFunctions
  } as ParsedSimulationKnobs;
};
