// import { lambertW0 } from "lambert-w";

import { Chicken, ChickenFarm } from "../model/ChickenFarm";

const u0 = 100; // Corresponds to a break-even time of 100 days at 100% premium (200 days at 50%)
const targetAvgAge = 60;
const adjustmentRate = 0.01;

const getAge = (k: number) => (c: Chicken) => k - c.bond.k0;
const avg = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;
// const tMaxArr = (premium: number) => 1 / (1 / lambertW0(Math.E / (1 + premium)) - 1);

export const asymmetricFarm = () =>
  new ChickenFarm({
    period: 365,
    u0,

    in0: {
      TOKEN: 1000,
      sTOKEN: 500
    },

    curve: (dk, u) => dk / (dk + u),

    grow: () => 0.05,
    spot: ({ stats }) => (stats.coop.TOKEN + stats.in.TOKEN) / stats.in.sTOKEN,
    point: () => targetAvgAge,
    gauge: ({ k, coop }) => avg(coop.map(getAge(k))),
    steer: ({ e, u }) => (e < 0 ? u * (1 - adjustmentRate) : u),
    hatch: ({ k }) => (k < 1000 ? 100 : 200),
    move: ({ dArr }) => (dArr < 0 ? "in" : null)
  });
