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
  u0: "30",
  in0: "[1, 1]",
  curve: "(dk, u) => dk / (dk + u)",

  grow: "() => 0.05",

  spot: `
({ stats: s }) => (
  s.coop.TOKEN +
  s.in.TOKEN +
  s.tollTOKEN * 0.5
) / s.in.sTOKEN`.trim(),

  point: "() => 30",

  gauge: `
({ k, coop }) => coop
  .map(({ bond: { k0 } }) => k - k0)
  .reduce((a, b) => a + b, 0)
  / (coop.length || 1)`.trim(),

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
