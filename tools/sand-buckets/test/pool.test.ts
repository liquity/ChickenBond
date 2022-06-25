import test from "ava";
import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "@ethersproject/contracts";
import { AlchemyProvider } from "@ethersproject/providers";
import { Decimal } from "@liquity/lib-base";

import { StableSwapMetaPool, StableSwapPool } from "../src/stable-swap/pool";

const totalSupplyAbi = ["function totalSupply() view returns (uint256)"];

const curvePoolAbi = [
  "function A() view returns (uint256)",
  "function fee() view returns (uint256)",
  "function admin_fee() view returns (uint256)",
  "function balances(uint256 i) view returns (uint256)",
  "function get_virtual_price() view returns (uint256)",
  "function get_dy(int128 i, int128 j, uint256 dx) view returns (uint256)",
  "function get_dy_underlying(int128 i, int128 j, uint256 dx) view returns (uint256)",
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

interface ClonePoolParams {
  pool: Contract;
  decimals: number[];
  blockTag: number;
  coin?: Contract;
  rates?: number[];
}

const clonePool = async ({ pool, decimals, blockTag, coin, rates }: ClonePoolParams) => {
  const [fee, adminFee, A, totalSupply] = await Promise.all([
    pool.fee({ blockTag }).then(decimalify()),
    pool.admin_fee({ blockTag }).then(decimalify()),
    pool.A({ blockTag }),
    (coin ?? pool).totalSupply({ blockTag }).then(numberify())
  ]);

  const balances = await Promise.all(
    decimals.map((d, i) => pool.balances(i, { blockTag }).then(numberify(d)))
  );

  return new StableSwapPool({
    n: decimals.length,
    A: A.toNumber(),
    fee: Number(fee.mul(1e8)),
    adminFee: Number(adminFee.mul(1e8)),
    balances,
    rates,
    totalSupply
  });
};

const metaPoolParams = (p: StableSwapMetaPool) => ({
  A: p.A,
  fee: p.fee,
  adminFee: p.adminFee,
  totalSupply: p.totalSupply,
  balances: p.balances,

  basePool: {
    n: p.basePool.n,
    A: p.basePool.A,
    fee: p.basePool.fee,
    adminFee: p.basePool.adminFee,
    totalSupply: p.basePool.totalSupply,
    balances: p.basePool.balances
  }
});

const approxEq = (epsilon: number) => (a: number, b: number) => a - b < epsilon;
const approxEq12D = approxEq(1e-12);
const approxEq6D = approxEq(1e-6);

test("StableSwapPool calculates the same virtual price and dy as on-chain", async t => {
  t.timeout(20000);

  const assert = <T extends unknown[]>(name: string, f: (...args: T) => boolean, ...args: T) => {
    t.log({ [name]: [...args] });
    t.true(f(...args));
  };

  const latestBlock = await provider.getBlock("latest");
  const blockTag = latestBlock.number - 10;

  const [baseVirtualPrice, lusdVirtualPrice] = await Promise.all([
    basePool.get_virtual_price({ blockTag }).then(numberify()),
    lusdPool.get_virtual_price({ blockTag }).then(numberify())
  ]);

  const baseClone = await clonePool({
    pool: basePool,
    decimals: [18, 6, 6],
    blockTag,
    coin: baseCoin
  });

  const { A, fee, adminFee, balances, totalSupply } = await clonePool({
    pool: lusdPool,
    decimals: [18, 18],
    blockTag
  });

  const lusdMeta = new StableSwapMetaPool({
    basePool: baseClone,
    A,
    fee,
    adminFee,
    balances,
    totalSupply
  });

  t.log({ blockTag });
  t.log(metaPoolParams(lusdMeta));

  assert("baseVirtualPrice", approxEq12D, baseVirtualPrice, baseClone.virtualPrice);
  assert("lusdVirtualPrice", approxEq12D, lusdVirtualPrice, lusdMeta.virtualPrice);

  const dx = 1e6;

  const baseDY = await basePool.get_dy(0, 1, Decimal.from(dx).hex, { blockTag }).then(numberify(6));
  assert("baseDY", approxEq6D, baseDY, baseClone.dy(0, 1, dx)[0]);

  const lusdDY01 = await lusdPool
    .get_dy_underlying(0, 1, Decimal.from(dx).hex, { blockTag })
    .then(numberify());
  assert("lusdDY01", approxEq6D, lusdDY01, lusdMeta.dyUnderlying(0, 1, dx));

  const lusdDY10 = await lusdPool
    .get_dy_underlying(1, 0, Decimal.from(dx).hex, { blockTag })
    .then(numberify());
  assert("lusdDY10", approxEq6D, lusdDY10, lusdMeta.dyUnderlying(1, 0, dx));
});

// // LUSD pool at block 14956624
// const p = new StableSwapMetaPool({
//   A: 500,
//   fee: 0.0004,
//   adminFee: 0.5,
//   totalSupply: 64834777.599998474,
//   balances: [
//     5524820.395973736, // LUSD
//     59122746.01788371 // 3CRV
//   ],

//   basePool: new StableSwapPool({
//     n: 3,
//     A: 2000,
//     fee: 0.0001,
//     adminFee: 0.5,
//     totalSupply: 1477659350.4041927,
//     balances: [
//       243777440.13653034, // DAI
//       242039603.039747, // USDC
//       1023877924.909114 // USDT
//     ]
//   })
// });

// console.log(p.dyUnderlying(0, 1, 1));
