// import { lambertW0 } from "lambert-w";

import { Chicken, ChickenFarm } from "../model/ChickenFarm";

const period = 365;
const u0 = 10;

const getAge = (k: number) => (c: Chicken) => k - c.bond.k0;
const avg = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;
// const tMaxArr = (premium: number) => 1 / (1 / lambertW0(Math.E / (1 + premium)) - 1);

export const cyclingFarm = () =>
  new ChickenFarm({
    period,
    u0,

    in0: {
      TOKEN: 1000,
      sTOKEN: 500
    },

    curve: (dk, u) => dk / (dk + u),
    point: ({ k }) => (k < 1000 ? 15 : 25),
    grow: () => 0.05,
    gauge: ({ k, coop }) => avg(coop.map(getAge(k))),
    steer: ({ k, e }) => e * (k < 1000 ? 10 : 20),
    spot: ({ stats }) => (stats.coop.TOKEN + stats.in.TOKEN) / stats.in.sTOKEN,
    hatch: () => 100,
    move: ({ dArr }) => (dArr < 0 ? "in" : null)
  });
