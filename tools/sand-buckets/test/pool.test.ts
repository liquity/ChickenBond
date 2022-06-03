import test from "ava";
import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "@ethersproject/contracts";
import { AlchemyProvider } from "@ethersproject/providers";
import { Decimal } from "@liquity/lib-base";

import { approxEq, StableSwapPool } from "../src/pool";

const totalSupplyAbi = ["function totalSupply() view returns (uint256)"];

const curvePoolAbi = [
  "function A() view returns (uint256)",
  "function fee() view returns (uint256)",
  "function admin_fee() view returns (uint256)",
  "function balances(uint256 i) view returns (uint256)",
  "function get_virtual_price() view returns (uint256)",
  "function get_dy(int128 i, int128 j, uint256 dx) view returns (uint256)",
  ...totalSupplyAbi
];

const provider = new AlchemyProvider();

const lusdPool = new Contract("0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA", curvePoolAbi, provider);
const basePool = new Contract("0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7", curvePoolAbi, provider);

const baseCoin = new Contract(
  "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490",
  totalSupplyAbi,
  provider
);

const TEN = Decimal.from(10);

const decimalify =
  (decimals = 18) =>
  (x: BigNumber) =>
    Decimal.fromBigNumberString(x.toHexString()).mul(TEN.pow(18 - decimals));

const numberify =
  (decimals = 18) =>
  (x: BigNumber) =>
    Number(decimalify(decimals)(x));

const clonePool = async (pool: Contract, decimals: number[], blockTag: number, coin?: Contract) => {
  const [fee, adminFee, A, totalSupply] = await Promise.all([
    pool.fee({ blockTag }).then(decimalify()),
    pool.admin_fee({ blockTag }).then(decimalify()),
    pool.A({ blockTag }),
    (coin ?? pool).totalSupply({ blockTag }).then(numberify())
  ]);

  const X = await Promise.all(
    decimals.map((d, i) => pool.balances(i, { blockTag }).then(numberify(d)))
  );

  return new StableSwapPool(
    decimals.length,
    Number(fee.mul(1e8)),
    Number(adminFee.mul(1e8)),
    A.toNumber(),
    X,
    totalSupply
  );
};

const approxEq10D = approxEq(1e-10);
const approxEq6D = approxEq(1e-6);

test("StableSwapPool calculates the same virtual price as on-chain", async t => {
  const latestBlock = await provider.getBlock("latest");
  const blockTag = latestBlock.number - 10;

  const [baseVirtualPrice, lusdVirtualPrice] = await Promise.all([
    basePool.get_virtual_price({ blockTag }).then(numberify()),
    lusdPool.get_virtual_price({ blockTag }).then(numberify())
  ]);

  const baseClone = await clonePool(basePool, [18, 6, 6], blockTag, baseCoin);
  const lusdClone = await clonePool(lusdPool, [18, 18], blockTag);
  lusdClone.X[1] *= baseVirtualPrice;

  t.true(approxEq10D(baseVirtualPrice, baseClone.getVirtualPrice()));
  t.true(approxEq10D(lusdVirtualPrice, lusdClone.getVirtualPrice()));

  const dx = 1e6;

  const baseDY = await basePool.get_dy(0, 1, Decimal.from(dx).hex, { blockTag }).then(numberify(6));
  t.true(approxEq6D(baseDY, baseClone.dy(0, 1, dx)[0]));

  const lusdDY = await lusdPool.get_dy(0, 1, Decimal.from(dx).hex, { blockTag }).then(numberify());
  t.true(approxEq6D(lusdDY, lusdClone.dy(0, 1, dx)[0] / baseVirtualPrice));

  // const initialLusd = 1000000;
  // const lp = lusdClone.addLiquidity([initialLusd, 0]);

  // for (let i = 0; i < 2; ++i) {
  //   lusdClone.exchange(0, 1, 100000);
  //   lusdClone.exchange(1, 0, 100000);
  // }

  // const finalLusd = lusdClone.removeLiquidityOneCoin(lp, 0);
  // console.log(finalLusd - initialLusd);
});
