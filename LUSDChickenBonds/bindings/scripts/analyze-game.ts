import fs from "fs";
import Enumerable, { IEnumerable } from "linq";
import { AddressZero } from "@ethersproject/constants";
import { BigNumber } from "@ethersproject/bignumber";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Decimal } from "@liquity/lib-base";
import { Batched } from "@liquity/providers";

import { connectToContracts } from "../src/contracts";
import manifest from "../deployments/goerli.json";

// const manifest = {
//   addresses: {
//     lusdToken: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
//     curvePool: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
//     curveBasePool: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
//     bondNFT: "0x68B1D87F95878fE05B998F19b66F4baba5De1aed",
//     bondNFTArtwork: "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e",
//     chickenBondManager: "0x59b670e9fA9D0A427751Af201D676719a970857b",
//     bLUSDToken: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
//     bLUSDCurveToken: "0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81",
//     bLUSDCurvePool: "0x6D544390Eb535d61e196c87d6B9c80dCD8628Acd",
//     curveLiquidityGauge: "0xB1eDe3F5AC8654124Cb5124aDf0Fd3885CbDD1F7",
//     yearnCurveVault: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
//     bammSPVault: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
//     yearnRegistry: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
//     prankster: "0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44",
//     underlingPrototype: "0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1",
//     troveManager: "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
//     lqtyToken: "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82",
//     lqtyStaking: "0x9A676e781A523b5d0C0e43731313A708CB607508",
//     pickleLQTYJar: "0x0B306BF915C4d645ff596e518fAf3F9669b97016",
//     pickleLQTYFarm: "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1",
//     curveGaugeController: "0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE",
//     curveCryptoPoolImplementation: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
//     curveLiquidityGaugeImplementation: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
//     curveTokenImplementation: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
//     curveFactory: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
//   },
//   chainId: 31337,
//   deploymentTimestamp: 1664096138,
//   startBlock: 1
// };

const BatchedJsonRpcProvider = Batched(JsonRpcProvider);

enum BondStatus {
  NonExistent,
  Active,
  ChickenedOut,
  ChickenedIn
}

const fromBlock = manifest.startBlock;
const toBlock = 7680311;
const speed = 24;
const oneWeek = (7 * 24 * 60 * 60) / speed;

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

const distributeLPReward = (
  currLPReward: number,
  prevRemainingLPReward: number,
  prevLPRewardAllocations: Partial<Record<string, number>>,
  prevLPShares: Partial<Record<string, number>>,
  timeSinceLastReward: number
) => {
  const rewardPaidOut = (prevRemainingLPReward * Math.min(timeSinceLastReward, oneWeek)) / oneWeek;

  return {
    lpRewardAllocations: Object.fromEntries(
      Object.entries(prevLPShares).map(([address, prevLPShare]) => [
        address,
        (prevLPRewardAllocations[address] ?? 0) + (prevLPShare ?? 0) * rewardPaidOut
      ])
    ),
    remainingLPReward: prevRemainingLPReward - rewardPaidOut + currLPReward
  };
};

const rpcUrl: string = process.env.RPC_URL || panic("No RPC_URL in env");
const provider = new BatchedJsonRpcProvider(rpcUrl);
provider.chainId = manifest.chainId;

const {
  lusdToken,
  bLUSDToken,
  bLUSDCurveToken,
  bondNFT,
  chickenBondManager,
  bLUSDCurvePool,
  curveLiquidityGauge
} = connectToContracts(provider, manifest.addresses);

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
    bLUSDSupply,
    bondSupply,
    bLUSDOraclePrice,
    bLUSDSpotPrice,
    lpTokenPoolPrice,
    curvePoolBLUSDBalance,
    curvePoolLUSDBalance,
    lpTotalSupply,
    backingRatio,
    pendingLUSD,
    acquiredLUSD,
    permanentLUSD
  ] = await Promise.all([
    lusdToken.tapAmount({ blockTag: toBlock }),
    bLUSDToken.totalSupply({ blockTag: toBlock }).then(numberify),
    bondNFT.totalSupply({ blockTag: toBlock }),
    bLUSDCurvePool
      .price_oracle({ blockTag: toBlock })
      .then(numberify)
      .then(x => 1 / x),
    bLUSDCurvePool.get_dy(0, 1, Decimal.ONE.hex, { blockTag: toBlock }).then(numberify),
    bLUSDCurvePool.lp_price({ blockTag: toBlock }).then(numberify),
    bLUSDCurvePool.balances(0, { blockTag: toBlock }).then(numberify),
    bLUSDCurvePool.balances(1, { blockTag: toBlock }).then(numberify),
    bLUSDCurveToken.totalSupply({ blockTag: toBlock }).then(numberify),
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
          bondAmount: numberify(bondData.lusdAmount),
          accruedBLUSD: numberify(accruedBLUSD)
        }))
      )
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

  const lpShares = lpTokenTransfers
    .select(x => ({
      block: x.blockNumber,
      index: x.logIndex,
      from: x.args._from,
      to: x.args._to,
      value: numberify(x.args._value)
    }))
    .where(x => x.value !== 0)
    .scan(
      {
        block: 0,
        index: 0,
        lpSupply: 0,
        lpBalances: {} as Partial<Record<string, number>>
      },
      ({ lpSupply, lpBalances }, { block, index, ...x }) => ({
        block,
        index,
        lpSupply:
          lpSupply + (x.from === AddressZero ? x.value : x.to === AddressZero ? -x.value : 0),
        lpBalances: {
          ...lpBalances,
          ...(x.from !== AddressZero ? { [x.from]: (lpBalances[x.from] ?? 0) - x.value } : {}),
          ...(x.to !== AddressZero ? { [x.to]: (lpBalances[x.to] ?? 0) + x.value } : {})
        }
      })
    )
    .select(({ lpSupply, lpBalances, ...x }) => ({
      ...x,
      lpShares: Object.fromEntries(
        Object.entries(lpBalances).map(([address, balance]) => [address, (balance ?? 0) / lpSupply])
      ) as Partial<Record<string, number>>
    }));

  const lpRewards = lusdTransfers
    .where(
      x => x.args.from === chickenBondManager.address && x.args.to === curveLiquidityGauge.address
    )
    .select(x => ({
      block: x.blockNumber,
      index: x.logIndex,
      lpReward: numberify(x.args.value)
    }));

  const blocks = lpShares
    .select(x => x.block)
    .union(lpRewards.select(x => x.block))
    .toArray();

  const blockTimestamps = await Promise.all(blocks.map(block => provider.getBlock(block)))
    .then(blocks => blocks.map(block => ({ block: block.number, timestamp: block.timestamp })))
    .then(toEnumerable);

  const { lpRewardAllocations, remainingLPReward } = (
    lpShares as IEnumerable<{
      block: number;
      index: number;
      lpShares?: Partial<Record<string, number>>;
      lpReward?: number;
    }>
  )
    .concat(lpRewards)
    .orderBy(x => x.block)
    .thenBy(x => x.index)
    .join(
      blockTimestamps,
      x => x.block,
      block => block.block,
      (x, { timestamp }) => ({ ...x, timestamp })
    )
    .aggregate(
      {
        timestamp: 0,
        lpShares: {} as Partial<Record<string, number>>,
        lpRewardAllocations: {} as Partial<Record<string, number>>,
        remainingLPReward: 0
      },
      (prev, curr) => ({
        timestamp: curr.timestamp,
        lpShares: curr.lpShares ?? prev.lpShares,

        ...distributeLPReward(
          curr.lpReward ?? 0,
          prev.remainingLPReward,
          prev.lpRewardAllocations,
          prev.lpShares,
          curr.timestamp - prev.timestamp
        )
      })
    );

  const players = lusdTransfers
    .where(x => x.args.from === AddressZero && x.args.value.eq(tapAmount))
    .select(x => x.args.to)
    .groupJoin(
      Enumerable.from(bonds),
      id,
      x => x.bonder,
      (player, bonds) => ({
        player,
        numBonds: bonds.count(),
        numActiveBonds: bonds.sum(x => x.active),
        numChickenedInBonds: bonds.sum(x => x.chickenedIn),
        numChickenedOutBonds: bonds.sum(x => x.chickenedOut),
        activeBonds: bonds.where(x => !!x.active)
      })
    )
    .join(
      lusdBalances,
      x => x.player,
      lusd => lusd.holder,
      (x, lusd) => ({ ...x, lusdBalance: lusd.balance })
    )
    .groupJoin(
      bLUSDBalances,
      x => x.player,
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
      x => x.player,
      lpToken => lpToken.holder,
      (x, lpToken) =>
        lpToken
          .select(lpToken => lpToken.balance)
          .defaultIfEmpty(0)
          .select(lpTokenBalance => ({ ...x, lpTokenBalance }))
    )
    .selectMany(id)
    .select(x => ({
      ...x,
      lpReward: lpRewardAllocations[x.player] ?? 0
    }));

  const calculatePortfolios = (suffix: string, bLUSDPrice: number, lpTokenPrice: number) => {
    const portfolios = players
      .select(({ activeBonds, ...x }) => ({
        ...x,
        pendingLUSDValue: activeBonds.sum(x => Math.max(x.bondAmount, x.accruedBLUSD * bLUSDPrice))
      }))
      .select(x => ({
        ...x,
        totalLUSDValue:
          x.lusdBalance +
          x.pendingLUSDValue +
          x.bLUSDBalance * bLUSDPrice +
          x.lpTokenBalance * lpTokenPrice +
          x.lpReward
      }))
      .orderByDescending(x => x.totalLUSDValue)
      .select(x => ({
        // Reorder columns
        player: x.player,
        numBonds: x.numBonds,
        numActiveBonds: x.numActiveBonds,
        numChickenedInBonds: x.numChickenedInBonds,
        numChickenedOutBonds: x.numChickenedOutBonds,
        totalLUSDValue: x.totalLUSDValue,
        pendingLUSDValue: x.pendingLUSDValue,
        lusdBalance: x.lusdBalance,
        bLUSDBalance: x.bLUSDBalance,
        lpTokenBalance: x.lpTokenBalance,
        lpReward: x.lpReward
      }));

    toCsv(portfolios.toArray(), `tmp/portfolios_${suffix}.csv`);
  };

  const bLUSDMigrationPrice = (acquiredLUSD + permanentLUSD) / bLUSDSupply;
  const lpTokenOriginalPrice = lpTokenPoolPrice * bLUSDOraclePrice;

  const getLpTokenProportionalWithdrawalValue = (bLUSDPrice: number) =>
    (curvePoolLUSDBalance + curvePoolBLUSDBalance * bLUSDPrice) / lpTotalSupply;

  const lpTokenOraclePrice = getLpTokenProportionalWithdrawalValue(bLUSDOraclePrice);
  const lpTokenSpotPrice = getLpTokenProportionalWithdrawalValue(bLUSDSpotPrice);
  const lpTokenMigrationPrice = getLpTokenProportionalWithdrawalValue(bLUSDMigrationPrice);
  const lpTokenRedemptionPrice = getLpTokenProportionalWithdrawalValue(backingRatio);

  calculatePortfolios("original", bLUSDOraclePrice, lpTokenOriginalPrice);
  calculatePortfolios("oracle", bLUSDOraclePrice, lpTokenOraclePrice);
  calculatePortfolios("spot", bLUSDSpotPrice, lpTokenSpotPrice);
  calculatePortfolios("migration", bLUSDMigrationPrice, lpTokenMigrationPrice);
  calculatePortfolios("redemption", backingRatio, lpTokenRedemptionPrice);

  const contractLUSDBalances = Enumerable.from(manifest.addresses)
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

  const contractBLUSDBalances = Enumerable.from(manifest.addresses)
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

  toCsv(contractBalances.toArray(), `tmp/contracts.csv`);

  fs.writeFileSync(
    "tmp/stats.csv",
    Object.entries({
      bLUSDOraclePrice,
      bLUSDSpotPrice,
      lpTokenOriginalPrice,
      lpTokenOraclePrice,
      lpTokenSpotPrice,
      lpTokenMigrationPrice,
      lpTokenRedemptionPrice,
      backingRatio,
      pendingLUSD,
      acquiredLUSD,
      permanentLUSD,
      lpTotalSupply,
      remainingLPReward
    })
      .map(row => row.join(","))
      .join("\n")
  );
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
