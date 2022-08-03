// import { lambertW0 } from "lambert-w";

import { ChickenFarm } from "../model/ChickenFarm";
import { lowpass } from "../utils";

const u0 = 100; // Corresponds to a break-even time of 100 days at 100% premium (200 days at 50%)

// const tMaxArr = (premium: number) => 1 / (1 / lambertW0(Math.E / (1 + premium)) - 1);

export const constantFarm = () => {
  const in0 = {
    TOKEN: 1,
    sTOKEN: 0.5
  };

  const f = lowpass(0.01, in0.TOKEN / in0.sTOKEN);

  return new ChickenFarm({
    period: 365,
    u0,
    in0,

    curve: (dk, u) => dk / (dk + u),

    grow: () => 0.05,
    point: () => 0,
    gauge: () => 0,
    steer: ({ u }) => u,
    spot: f(({ stats }) => (stats.coop.TOKEN + stats.in.TOKEN) / stats.in.sTOKEN),
    hatch: () => 100,
    move: ({ dArr }) => (dArr < 0 ? "in" : null)
  });
};
