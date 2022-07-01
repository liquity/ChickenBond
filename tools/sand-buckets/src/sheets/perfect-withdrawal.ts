import { balancingOneCoinWithdrawal, xyFromDydx } from "../stable-swap/math";
import { StableSwapPool } from "../stable-swap/pool";

const ROWS = 1000;
const As = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000];
const D = 1e3;
const fee = 0.0004;
const adminFee = 0.5;

console.log(["Initial dx/dy", ...As.map(A => `A=${A}`)].join(","));

for (let i = 1; i < ROWS; ++i) {
  const dxdy = i > ROWS / 2 ? 1 + ROWS * (fee / 8) + (i - ROWS / 2) : 1 + i * (fee / 4);

  const rois = As.map(A => {
    const [y, x] = xyFromDydx(A, D)(dxdy);
    const p = new StableSwapPool({ n: 2, A, fee, adminFee, balances: [x, y] });
    const lp = balancingOneCoinWithdrawal(p)(x, y);
    const lpV = lp * p.virtualPrice;
    const dx = p.removeLiquidityOneCoin(lp, 0);
    return (dx - lpV) / lpV;
  });

  console.log([dxdy, ...rois].join(","));
}
