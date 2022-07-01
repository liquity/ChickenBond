import { xyFromDydx } from "../stable-swap/math";
import { StableSwapPool } from "../stable-swap/pool";

const ROWS = 1000;
const As = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000];
const dx = 1;
const D = 1e9; // Make it big, so that our deposit of 1 is tiny in comparison
const fee = 0.0004;
const adminFee = 0.5;

console.log(["dy/dx", ...As.map(A => `A=${A}`)].join(","));

for (let i = 1; i < ROWS; ++i) {
  const dydx = i > ROWS / 2 ? 1 + ROWS * (fee / 80) + (i - ROWS / 2) : 1 + i * (fee / 40);

  const profits = As.map(A => {
    const [x, y] = xyFromDydx(A, D)(dydx);
    const p = new StableSwapPool({ n: 2, A, fee, adminFee, balances: [x, y] });
    const lp = p.addLiquidity([dx, 0]);
    const lpV = lp * p.virtualPrice;
    return (lpV - dx) / dx;
  });

  console.log([dydx, ...profits].join(","));
}
