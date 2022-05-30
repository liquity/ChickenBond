# LUSD Chicken Bonds - Technical Readme

LUSD Chicken bonds is a specific implementation of the General Chicken Bonds model described in the whitepaper.

The system has two goals: 

- To acquire permanent protocol-owned liquidity by offering a boosted yield on deposited LUSD
- To stabilize the LUSD dollar peg on the Curve.fi LUSD-3CRV metapool (the venue where the majority of LUSD trading volume has historically occurred).

## Overview of mechanics

The core mechanics remain the same as outlined in the whitepaper. A user bonds LUSD, and accrues an bLUSD balance over time on a smooth sub-linear schedule.

At any time they may **chicken out** and reclaim their entire principal, or **chicken in** and give up their principal in exchange for freshly minted bLUSD.

bLUSD may always be redeemed for a proportional share of the system’s acquired LUSD.

However, LUSD Chicken Bonds contains additional functionality for the purposes of peg stabilization and migration. The funds held by the protocol are split across two yield-bearing Yearn vaults, referred to as the **Yearn SP Vault** and the **Yearn Curve Vault**. The former deposits funds to the Liquity Stability Pool, and the latter deposits funds into the Curve LUSD3CRV MetaPool.

The LUSD Chicken Bonds system has public shifter functions which are callable by anyone and move LUSD between the vaults, subject to Curve spot price constraints. The purpose of these is to allow anyone to tighten the Curve pool’s LUSD spot price dollar peg, by moving system funds between the yield-bearing vaults (and thus to or from the Curve pool).

Additionally, the system contains logic for a “migration mode” which may be triggered only by a single privileged admin - namely the Yearn Finance governance address:
0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52

When Yearn upgrade their vaults from v2 to v3, they will freeze deposits and cease harvesting yield. Migration mode allows the LUSD Chicken Bonds system to wind down gracefully, and allows all funds to be redeemed or withdrawn, so that users, if they so choose, may redeposit their funds to a new LUSD Chicken Bonds version which will be connected up to Yearn’s v3 vaults.


## Project structure

- `papers` - General Chicken Bonds Whitepaper variants
- `tools` - various fuzz tests and simulations
- `modelling/ChickenBonds` - Macroeconomic modelling
- `LUSDChickenBonds`  - core LUSD Chicken Bonds folder containing the Foundry project
- `LUSDChickenBonds/YearnContracts/` - annotated smart contract code for the deployed mainnet integrations: the Yearn vaults and strategies.
- `LUSDChickenBonds/src/ExternalContracts/` - Mock external integrations for development testing
- `LUSDChickenBonds/src/` - core system smart contracts 
-  `LUSDChickenBonds/src/test/` - Foundry tests in Solidity for both development and mainnet fork testing. Contains unit tests and simple Foundry fuzz tests.
- `LUSDChickenBonds/src/Interfaces/` - Solidity interfaces for core system contracts and external integrations
- `LUSDChickenBonds/src/Proxy/` - Contains a Chicken Bonds operations script for combining transactions, for use with DSProxy
- `LUSDChickenBonds/src/utils` - Contains basic math and logging utilities used in the core smart contracts.

## Running the project

ChickenBonds is a Foundry project in `/LUSDChickenBonds`.  

Install Foundry:
https://github.com/gakonst/foundry

### Running tests

The bulk of significant testing has been done using a mainnet fork, since ChickenBonds will heavily depend on the deployed Yearn vaults and Curve pool.

For mainnet fork testing in Foundry, please set the env variable `ETH_RPC_URL` equal to your API key for a Ethereum RPC node service such as Alchemy or Infura. Run all mainnet tests with:
forge test --fork-url $ETH_RPC_URL

Core contracts are found in `src`, and tests are in `src/test/`

## Global Liquidity Buckets

As per the whitepaper, LUSD Chicken Bonds utilizes 3 global LUSD buckets: the **pending** bucket, the **acquired** bucket, and the **permanent** bucket, all of which earn yield.

The **pending** bucket contains the LUSD of all open bonds. It is untouched by redemptions. 

The **permanent** bucket contains all protocol-owned LUSD. It is untouched by redemptions, and remains permanently owned by the protocol in normal mode.

The **acquired** bucket contains all LUSD held by the protocol which may be redeemed by burning bLUSD. 



### Yield sources

The Chicken Bonds system deposits LUSD to external Yearn vaults - the Yearn SP vault, and the Yearn Curve vault -  which generate yield.

All funds held by the system (pending, acquired and permanent) are held inside one of the vaults and generate yield - all of which is added to the acquired bucket.


### Individual Liquidity Buckets

The global **permanent** and **acquired** buckets are split across both Yearn SP vault and the Curve pool (with its LP tokens deposited to the Yearn Curve vault for yield generation).  

The **pending** bucket is held purely by the Yearn SP vault in normal mode, and purely by the LUSD Silo in migration mode.

The buckets are split in the following manner in normal mode:

- Pending LUSD in the Yearn SP vault (constitutes all pending LUSD)
- Permanent LUSD in the Yearn SP Vault
- Permanent LUSD in Curve
- Acquired LUSD in the Yearn SP vault
- Acquired LUSD in Curve

In migration mode, no funds are permanent. The buckets are split in this manner:

- Pending LUSD in the LUSD Silo (constitutes all pending LUSD)
- Acquired LUSD in the LUSD Silo
- Acquired LUSD in Curve

### Example buckets state

![Chicken bond buckets drawio](https://user-images.githubusercontent.com/701095/170958185-fb2242aa-07f9-41ac-9384-294c5ecfa4db.png)

_This diagram shows an example state of the individual buckets in normal mode.  Exact quantities in each individual **acquired** and **permament** bucket will vary over time - their sizes depend on the history of shift events and the magnitude and and timing of early chicken-ins._



### Flow of funds between individual buckets

For the global permanent and acquired buckets, the split is updated by shifter functions which move funds between the SP vault and the Curve pool. Here is an outline of how funds flow between buckets due to various system operations:

`createBond:` deposits the bonded LUSD to the Yearn SP vault pending bucket

`chickenIn (normal mode):`
- Moves some portion of bond’s LUSD from Yearn SP vault pending bucket to Yearn SP vault acquired bucket
- Moves the remainder of bond’s LUSD from Yearn SP vault pending bucket to Yearn SP vault permanent bucket

`chickenIn (migration mode):`
- Moves some portion of bond’s LUSD from the LUSD Silo pending bucket to Yearn SP vault acquired bucket
- Refund the remainder of bond’s LUSD from LUSD Silo pending bucket to the caller

`chickenOut (normal mode):` Withdraws all of the bond’s LUSD from the Yearn SP vault pending bucket

`chickenOut (migration mode):` Withdraws all of the bond’s LUSD from the LUSD Silo pending bucket

`redeem(normal mode):` Pulls funds proportionally from the Yearn SP vault acquired bucket and the Curve acquired bucket (sends yTokens, and does not unwrap to LUSD)

`redeem(migration mode)`: Pulls redeemed funds proportionally from the LUSD Silo acquired bucket (as LUSD) and the Curve acquired bucket (as yTokens)

`shiftLUSDFromSPToCurve`:
- Moves some LUSD from the Yearn SP vault acquired bucket to the Curve acquired bucket
- Moves some LUSD from the Yearn SP vault permanent bucket to the Curve permanent bucket

`shiftLUSDFromCurveToSP:`
- Moves some LUSD from Curve acquired bucket to the Yearn SP vault acquired bucket
- Moves some LUSD from Curve permanent bucket to the Yearn SP vault permanent bucket


### Tracking individual bucket quantities

The **pending** bucket and individual **permanent** buckets are tracked by state variables in `ChickenBondManager`, and updated when funds are added/removed.  Specifically, these state variables are:

- `totalPendingLUSD`
- `permanentLUSDInYearnSPVault`
- `permanentLUSDInYearnCurveVault`

Individual **acquired** buckets are not explicitly tracked via state variables. Rather, the acquired LUSD in a given pool (Yearn SP vault or Curve) is calculated based on the total funds held in the pool, minus any pending and permanent funds in that pool.  

The following getter functions in the smart contract perform these calculations for individual acquired buckets:
- `getAcquiredLUSDInSPVault()`
- `getAcquiredLUSDInCurve()`
- `getAcquiredLUSDInLUSDSilo()`


## Shifter functions

The two system shifter functions are public and permissionless.  They are: `shiftLUSDFromSPToCurve` and `shiftLUSDFromCurveToSP`.

When the LUSD spot price in the Curve is > 1, anyone may shift LUSD from the Liquity Stability Pool to the Curve pool (routed via the corresponding Yearn vaults), thus moving the spot price back toward 1 - improving the dollar peg. Conversely, when the spot price is < 1, anyone may shift LUSD from the Curve pool and into the Stability Pool, which increases the price toward 1.

Crucially, an LUSD shift transaction only succeeds if it improves the Curve spot price by bringing it closer to 1 - yet, must not cause it to cross the boundary of 1. Shifter functions are enabled in normal mode and disabled in migration mode.


## Core smart contract architecture

- `ChickenBondManager:` this contract contains the majority of system logic. It contains public state-changing functionality for bonding, chickening in and out, shifting protocol funds between vaults, and redeeming bLUSD. It also contains several getters for the various bucket quantities.


- `BondNFT:` is the ERC721 which mints bond NFTs upon creation.  A bond NFT entitles the holder to take actions related to the corresponding bond i.e. chickening in or out.


- `LUSDSilo:` is a simple container contract that is only utilized in migration mode. Upon migration, it receives all of the system funds that were previously held in the SP vault. 

- `BLUSDToken:` the token contract for bLUSD. Standard ERC20 functionality.


## External integrations

LUSD Chicken bonds is connected to three external contracts which are already live on mainnet:

- Yearn SP Vault.  Chicken Bonds deposits funds here upon bond creation, to earn yield. This vault primarily utilizes the Liquity Stability Pool (SP) and secondarily the Tokemak LUSD reactor, which each generate a return on deposited LUSD, in LUSD.

- Curve LUSD3CRV MetaPool. Chicken Bonds deposits LUSD here and receives the LUSD3CRV LP token. This is in turn deposited to the Yearn Curve vault.

- Yearn Curve Vault. LUSD3CRV is deposited here, and the vault generates a return on the deposit, paid in LUSD3CRV.

Each Yearn vault is periodically manually harvested by the Yearn team in order to realize the yield in terms of the deposited token.


## Public state-changing functions

- `createBond(_lusdAmount):` creates a bond for the user and mints a bond NFT to their address. A user may create multiple bonds.

- `chickenOut(bondID):` removes the given bond from the system and burns the bond NFT. Refunds the bonded LUSD to the caller.

- `chickenIn(bondID):` removes the given bond from the system and burns the bond NFT. Makes a portion of the bonded LUSD “acquired” and redeemable, and the remainder of the bonded LUSD permanently protocol-owned.  The split between these two quantities is determined such that the global system backing ratio remains constant.

- `redeem(_bLUSDAmount):` Burns the provided bLUSD, and pulls funds from the system’s acquired LUSD in an amount proportional to the fraction of total bLUSD burned.  Funds are drawn proportionally from the Yearn SP and Curve vaults and sent to the redeemer.


- `shiftLUSDFromSPToCurve(_lusdAmount):` Shifts the given LUSD amount from the Yearn SP vault to Curve, and deposits the received LP tokens to the Curve vault. Pulls funds from the acquired and permanent buckes in the SP vault, and moves them to the acquired and permanent buckets in the Curve vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `shiftLUSDFromCurveToSP(_lusdAmount):` Shifts the given LUSD amount from the Curve to the Yearn SP vault. Pulls funds from the Curve acquired and permanent buckets, and moves them to the acquired and permanent buckets in the SP vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `sendFeeShare(_lusdAmount):` Callable only by Yearn Governance. Transfers the provided LUSD to the ChickenBondManager contract, and deposits it to the Yearn SP Vault.

- `activateMigration():` Callable only by Yearn Governance. Pulls all funds from the Yearn SP vault and transfers them to a trusted Silo contract. Moves all funds in permanent buckets to their corresponding acquired buckets, thus making all system funds (except for the pending bucket) redeemable.

## Controller
The system incorporates an asymmetrical controller, designed to maintain the economic attractiveness of bonding. Without any form of control it seems likely that the break-even bonding time would increase. As the system matures, it may be necessary to steepen the bLUSD accrual curve. Controlling the accrual curve successfully should have the effect of keeping the break-even time and optimal rebonding time below some acceptable upper bound.

### Accrual parameter control

The "alpha" parameter of the accrual function variable (call it `accrualParameter` in the code) and implement a simple asymmetrical controller that adjusts this parameter in one direction only (reducing it by a small percentage, making the accrual slightly faster each time).

The controller's logic is simple in theory: every `accrualAdjustmentPeriodSeconds` seconds, determine the size-weighted average age of pending bonds (in seconds) and compare it to `targetAverageAgeSeconds`. If the average is higher than the target, reduce `accrualParameter` by a fixed percentage (`accrualAdjustmentRate`).

The reduction results in an immediate step-increase of the accrued bLUSD amounts of pending bonds. This is expected to increase the likelihood of bonders chickening in, which would result in a reduction of the average outstanding bond age, eventually dropping below the target.

### Implementation notes

Even though there's no way to "schedule" periodic tasks to be executed in EVM, the controller is implemented to appear as if adjustments were being performed regularly at timestamps given by the formula `deploymentTimestamp + n * accrualAdjustmentPeriodSeconds`, where `n` is a positive integer. This means that all view functions that evaluate a bond's accrued bTKN now calculate the number of adjustments (if any) that need to be applied to accrualParameter under the hood, and use an updated accrual parameter when evaluating the accrual function.

Mutating functions that have an effect on the average age (`createBond()`, `chickenOut()` and `chickenIn()`) also start by calculating the updated value of `accrualParameter` and committing it to storage before making any changes that would change the average age. This is to ensure that `accrualParameter` gets updated to the same value that it would have been if the update was made at exactly the most recent "scheduled" adjustment timestamp.

## Migration mode

Yearn will in the not-too-distant future (<11 months) deploy v3 vaults.  Around that time, they will deprecate existing v2 vaults and deploy replacement v3 versions. Specifically, they will:

- Disable deposits to the deprecated v2 vault
- Cease harvesting yield on the deprecated v2 vault

In case of deprecation of the SP LUSD and Curve LUSD3CRV vaults, we'd like to launch a new Chicken Bonds system that is hooked up to v3 vaults, and encourage users to migrate their funds. 

We need to ensure that when Yearn deprecate the v2 vaults:

- All LUSD can be extracted from the old Chicken Bonds system, via a combination of redemptions and chicken-outs 

- LUSD does not remain in the Yearn SP vault. The ceasing of harvesting means that if liquidations occur, the liquidation ETH gain would not be recycled back to LUSD, causing a permanent loss to the Chicken Bonds system, and by extension, losses to bonders & bLUSD holders.

A proxy upgrade pattern was briefly considered: it would have been simple to give Yearn control over setting the v3 vault addresses in `ChickenBondManager`, and directly migrating system funds from v2 -> v3 vaults. However, as Chicken Bonds may one day hold hundreds of millions of dollars worth of funds, we deemed this too great a responsibility - it would in theory be possible for a rogue actor with such capability to create fake v3 vault contracts and drain all Chicken Bond system funds. 

For better trust minimization we instead opted for a "wind down" approach where Yearn governance can _prepare_ the system for migration by making all funds redeemable, and moving the LUSD contents of the Yearn SP vault to a safe "Silo" that is not exposed to Liquity liquidations. When suitable v3 vaults are live, we would deploy a fresh instance of LUSD Chicken Bonds connected up to them - and encourage users to manually migrate.

### Migration functionality

The system contains an `LUSDSilo` contract which is empty and unused during normal mode.

The `ChickenBondManager` contract contains a function `activateMigration`, callable one-time and only by Yearn Governance. Yearn have agreed to call this function when they deprecate the v2 vaults that Chicken Bonds is connected to. `activateMigration` does the following:

- Raise a `migration` mode flag
- Move all permanent LUSD from permanent bucket to acquired bucket (thus making it redeemable)
- Shift all LUSD currently in the Yearn SP vault to the LUSD Silo (thus relocating all pending LUSD, and some of the acquired LUSD, to the Silo)

### Post-migration logic

Migration mode activation triggers the following logic changes:

`createBond`: disabled

`shiftLUSDFromSPToCurve`, `shiftLUSDFromCurveToSP`: disabled

`chickenOut`: LUSD is withdrawn from the Curve pool's pending LUSD bucket (since, post-migration, all pending LUSD is now in Curve)

`chickenIn`:
- Does not increase the permanent bucket with the LUSD surplus
- Instead, refunds the surplus LUSD to the bonder
- No first-chicken-in yield is sent to AMM reward. Reasoning: yields should cease after yearn trigger migration mode
- No tax is sent to AMM rewards. Reasoning: no need to maintain AMM LP incentives in migration mode. It's fine and desirable for LPs to pull funds and redeem their bLUSD. 

`redeem`: pulls funds proportionally from the Silo acquired bucket (as LUSD) and the Curve acquired bucket (as yTokens for the Yearn Curve vault)

## Fee share functionality

We will participate in Yearn's partnership program whereby they send a share of the vault fees back to the Chicken Bonds system:
https://docs.yearn.finance/partners/introduction

_"any protocol that integrates yVaults can earn up to a 50% profit share from their contributed TVL."_

We assume they will send us the fee share in LUSD from the Yearn governance address. `ChickenBondManager` has a `sendFeeShare` function, callable only by them, which transfers the LUSD and deposits it to the Yearn SP vault in normal mode. It's disabled in migration mode, since harvests/fees will not occur.
