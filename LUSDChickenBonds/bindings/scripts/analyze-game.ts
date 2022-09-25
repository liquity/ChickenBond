import fs from "fs";
import Enumerable, { IEnumerable } from "linq";
import { AddressZero } from "@ethersproject/constants";
import { BigNumber } from "@ethersproject/bignumber";
import { AlchemyProvider } from "@ethersproject/providers";
import { Decimal } from "@liquity/lib-base";
import { Batched } from "@liquity/providers";

import { connectToContracts } from "../src/contracts";
import goerli from "../deployments/goerli.json";

const BatchedAlchemyProvider = Batched(AlchemyProvider);

enum BondStatus {
  NonExistent,
  Active,
  ChickenedOut,
  ChickenedIn
}

const fromBlock = goerli.startBlock;
const toBlock = 7578204;

// const contractAddresses = new Set(Object.values(goerli.addresses));

const id = <T>(t: T) => t;

const panic = <T>(message: string): T => {
  throw new Error(message);
};

const decimalify = (n: BigNumber) => Decimal.fromBigNumberString(n.toHexString());
const numberify = (n: BigNumber) => Number(decimalify(n));

const toEnumerable = <T>(arr: T[]) => Enumerable.from(arr);

const toCsv = (arr: Record<string, unknown>[], filename: string) => {
  fs.writeFileSync(
    filename,
    [Object.keys(arr[0]).join(","), ...arr.map(row => Object.values(row).join(","))].join("\n")
  );
};

const getBalances = (
  transfers: IEnumerable<{
    args: {
      from: string;
      to: string;
      value: BigNumber;
    };
  }>
) => {
  const t = transfers.select(({ args }) => ({
    from: args.from,
    to: args.to,
    value: numberify(args.value)
  }));

  return t
    .select(x => ({
      holder: x.from,
      balanceChange: -x.value
    }))
    .concat(
      t.select(x => ({
        holder: x.to,
        balanceChange: x.value
      }))
    )
    .groupBy(
      x => x.holder,
      x => x.balanceChange,
      (holder, balanceChanges) => ({
        holder,
        balance: balanceChanges.sum()
      })
    );
};

// const getBalanceHistories = (
//   transfers: IEnumerable<{
//     blockNumber: number;
//     args: {
//       from: string;
//       to: string;
//       value: BigNumber;
//     };
//   }>
// ) => {
//   const t = transfers
//     .select(x => ({
//       block: x.blockNumber,
//       from: x.args.from,
//       to: x.args.to,
//       value: numberify(x.args.value)
//     }))
//     .orderBy(x => x.block);

//   return t
//     .select(x => ({
//       block: x.block,
//       holder: x.from,
//       balanceChange: -x.value
//     }))
//     .merge(
//       t.select(x => ({
//         block: x.block,
//         holder: x.to,
//         balanceChange: x.value
//       }))
//     )
//     .groupBy(
//       x => x.holder,
//       id,
//       (holder, x) =>
//         x.groupBy(
//           x => x.block,
//           x => x.balanceChange,
//           (block, balanceChange) => ({
//             block,
//             holder,
//             balanceChange: balanceChange.sum()
//           })
//         )
//     ).toArray();
// };

const alchemyApiKey: string = process.env.ALCHEMY_API_KEY || panic("No ALCHEMY_API_KEY in env");
const provider = new BatchedAlchemyProvider("goerli", alchemyApiKey);
provider.chainId = goerli.chainId;

const { lusdToken, bLUSDToken, bLUSDCurveToken, bondNFT, chickenBondManager, bLUSDCurvePool } =
  connectToContracts(provider, goerli.addresses);

const main = async () => {
  const lusdTransfers = await provider
    .getLogs({ ...lusdToken.filters.Transfer(), fromBlock, toBlock })
    .then(logs => lusdToken.extractEvents(logs, "Transfer"))
    .then(toEnumerable);

  const bLUSDTransfers = await provider
    .getLogs({ ...bLUSDToken.filters.Transfer(), fromBlock, toBlock })
    .then(logs => bLUSDToken.extractEvents(logs, "Transfer"))
    .then(toEnumerable);

  const lpTokenTransfers = await provider
    .getLogs({ ...bLUSDCurveToken.filters.Transfer(), fromBlock, toBlock })
    .then(logs => bLUSDCurveToken.extractEvents(logs, "Transfer"))
    .then(toEnumerable);

  const [
    tapAmount,
    bondSupply,
    bLUSDPrice,
    lpTokenPrice,
    backingRatio,
    pendingLUSD,
    acquiredLUSD,
    permanentLUSD
  ] = await Promise.all([
    lusdToken.tapAmount({ blockTag: toBlock }).then(numberify),
    bondNFT.totalSupply({ blockTag: toBlock }),
    bLUSDCurvePool
      .price_oracle({ blockTag: toBlock })
      .then(numberify)
      .then(x => 1 / x),
    bLUSDCurvePool.lp_price({ blockTag: toBlock }).then(numberify),
    chickenBondManager.calcSystemBackingRatio({ blockTag: toBlock }).then(numberify),
    chickenBondManager.getPendingLUSD({ blockTag: toBlock }).then(numberify),
    chickenBondManager.getTotalAcquiredLUSD({ blockTag: toBlock }).then(numberify),
    chickenBondManager.getPermanentLUSD({ blockTag: toBlock }).then(numberify)
  ]);

  const bonds = await Promise.all(
    [...new Array(bondSupply.toNumber()).keys()]
      .map(i => i + 1)
      .map(tokenID =>
        Promise.all([
          bondNFT.ownerOf(tokenID, { blockTag: toBlock }),
          chickenBondManager.getBondData(tokenID, { blockTag: toBlock }),
          chickenBondManager.calcAccruedBLUSD(tokenID, { blockTag: toBlock })
        ]).then(([bonder, bondData, accruedBLUSD]) => ({
          tokenID,
          bonder,
          active: bondData.status === BondStatus.Active ? 1 : 0,
          chickenedIn: bondData.status === BondStatus.ChickenedIn ? 1 : 0,
          chickenedOut: bondData.status === BondStatus.ChickenedOut ? 1 : 0,
          pendingLUSDValue:
            bondData.status === BondStatus.Active
              ? Math.max(numberify(bondData.lusdAmount), numberify(accruedBLUSD) * bLUSDPrice)
              : 0
        }))
      )
  );

  const bonders = Enumerable.from(bonds).groupBy(
    x => x.bonder,
    id,
    (bonder, x) => ({
      bonder,
      numBonds: x.count(),
      numActiveBonds: x.sum(x => x.active),
      numChickenedInBonds: x.sum(x => x.chickenedIn),
      numChickenedOutBonds: x.sum(x => x.chickenedOut),
      pendingLUSDValue: x.sum(x => x.pendingLUSDValue)
    })
  );

  const lusdBalances = getBalances(lusdTransfers);
  const bLUSDBalances = getBalances(bLUSDTransfers);

  const lpTokenBalances = getBalances(
    lpTokenTransfers.select(({ args }) => ({
      args: {
        // Some elbow grease needed
        from: args._from,
        to: args._to,
        value: args._value
      }
    }))
  );

  const mints = lusdTransfers
    .select(x => x.args)
    .where(x => x.from === AddressZero)
    .groupBy(
      x => x.to,
      id,
      (minter, mint) => ({ minter, count: mint.count() })
    );

  const portfolios = bonders
    .join(
      lusdBalances,
      x => x.bonder,
      lusd => lusd.holder,
      (x, lusd) => ({ ...x, lusdBalance: lusd.balance })
    )
    .groupJoin(
      bLUSDBalances,
      x => x.bonder,
      bLUSD => bLUSD.holder,
      (x, bLUSD) =>
        bLUSD
          .select(bLUSD => bLUSD.balance)
          .defaultIfEmpty(0)
          .select(bLUSDBalance => ({ ...x, bLUSDBalance }))
    )
    .selectMany(id)
    .groupJoin(
      lpTokenBalances,
      x => x.bonder,
      lpToken => lpToken.holder,
      (x, lpToken) =>
        lpToken
          .select(lpToken => lpToken.balance)
          .defaultIfEmpty(0)
          .select(lpTokenBalance => ({ ...x, lpTokenBalance }))
    )
    .selectMany(id)
    .join(
      mints,
      x => x.bonder,
      mint => mint.minter,
      (x, mint) => ({ ...x, tapCount: mint.count })
    )
    .select(x => ({
      ...x,
      totalLUSDValue:
        x.lusdBalance +
        x.pendingLUSDValue +
        x.bLUSDBalance * bLUSDPrice +
        x.lpTokenBalance * lpTokenPrice -
        (x.tapCount - 1) * tapAmount // no cheating
    }))
    .orderByDescending(x => x.totalLUSDValue);

  toCsv(portfolios.toArray(), "tmp/portfolios.csv");

  const contractLUSDBalances = Enumerable.from(goerli.addresses)
    .select(x => ({
      contract: x.key,
      address: x.value
    }))
    .join(
      lusdBalances,
      x => x.address,
      lusd => lusd.holder,
      (x, lusd) => ({ ...x, lusdBalance: lusd.balance })
    );

  const contractBLUSDBalances = Enumerable.from(goerli.addresses)
    .select(x => ({
      contract: x.key,
      address: x.value
    }))
    .join(
      bLUSDBalances,
      x => x.address,
      bLUSD => bLUSD.holder,
      (x, bLUSD) => ({ ...x, bLUSDBalance: bLUSD.balance })
    );

  const contractBalances = contractLUSDBalances
    .groupJoin(
      contractBLUSDBalances
        .groupJoin(
          contractLUSDBalances,
          bLUSD => bLUSD.address,
          lusd => lusd.address,
          (bLUSD, lusd) =>
            lusd
              .select(lusd => lusd.lusdBalance)
              .defaultIfEmpty(0)
              .select(lusdBalance => ({ ...bLUSD, lusdBalance }))
        )
        .selectMany(id),
      x => x.address,
      bLUSD => bLUSD.address,
      (x, bLUSD) =>
        bLUSD
          .select(bLUSD => bLUSD.bLUSDBalance)
          .defaultIfEmpty(0)
          .select(bLUSDBalance => ({ ...x, bLUSDBalance }))
    )
    .selectMany(id)
    .select(x => ({
      // Reorder columns
      contract: x.contract,
      address: x.address,
      lusdBalance: x.lusdBalance,
      bLUSDBalance: x.bLUSDBalance
    }));

  toCsv(contractBalances.toArray(), "tmp/contracts.csv");

  fs.writeFileSync(
    "tmp/stats.csv",
    Object.entries({
      bLUSDPrice,
      lpTokenPrice,
      backingRatio,
      pendingLUSD,
      acquiredLUSD,
      permanentLUSD
    })
      .map(row => row.join(","))
      .join("\n")
  );
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
