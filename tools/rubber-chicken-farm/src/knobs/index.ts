import { ChickenFarmParams, ChickenFarmSteerParams } from "../model/ChickenFarm";

const steerOptions = new Set(["asymmetric", "pid"] as const);

export type SteerOption = typeof steerOptions extends Set<infer T> ? T : never;

export const validateSteerOption = (value: string): SteerOption => {
  if (!(steerOptions as Set<string>).has(value)) {
    throw new Error(`Invalid SteerOption value "${value}"`);
  }

  return value as SteerOption;
};

export interface ParsedSimulationKnobs extends Omit<ChickenFarmParams, "period" | "steer"> {
  selectedSteer: SteerOption;

  asymmetricAdjustmentRate: number;

  pidKp: (params: ChickenFarmSteerParams) => number;
  pidKi: (params: ChickenFarmSteerParams) => number;
  pidKd: (params: ChickenFarmSteerParams) => number;
}

export type SimulationKnobs = { [P in keyof ParsedSimulationKnobs]: string };

export const simulationDefaults: SimulationKnobs = {
  u0: "100",
  in0: "[1000, 500]",
  curve: "(dk, u) => dk / (dk + u)",

  grow: "() => 0.05",

  spot: `
({ stats: s }) =>
  (s.coop.TOKEN + s.in.TOKEN) / s.in.sTOKEN`.trim(),

  point: "() => 60",

  gauge: `
({ k, coop }) => coop
  .map(({ bond: { k0 } }) => k - k0)
  .reduce((a, b) => a + b, 0)
  / (coop.length || 1)`.trim(),

  hatch: "() => 100",

  move: `
({ k, u, premium: p, bond: { k0 } }) =>
  k >= Math.round(k0 + u / (
    1 / W(Math.E / (1 + Math.max(p, 0))) - 1
  )) ? "in" : null`.trim(),

  selectedSteer: "asymmetric",

  asymmetricAdjustmentRate: "0.1",

  pidKp: "() => 1",
  pidKi: "() => 0",
  pidKd: "() => 0"
};

export const parseSimulationKnobs = (knobs: Readonly<SimulationKnobs>): ParsedSimulationKnobs => {
  const { u0, in0, selectedSteer, asymmetricAdjustmentRate, ...functions } = knobs;

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

    u0: Number(u0),
    asymmetricAdjustmentRate: Number(asymmetricAdjustmentRate),
    selectedSteer: validateSteerOption(selectedSteer),

    ...parsedFunctions
  } as ParsedSimulationKnobs;
};
