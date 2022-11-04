# LUSD Chicken Bonds - Technical Readme

LUSD Chicken bonds is a specific implementation of the General Chicken Bonds model described in the whitepaper.

The system has two goals: 

- To acquire permanent protocol-owned liquidity by offering a boosted yield on deposited LUSD
- To stabilize the LUSD dollar peg on the Curve.fi LUSD-3CRV metapool (the venue where the majority of LUSD trading volume has historically occurred).

## Overview of mechanics

The core mechanics remain the same as outlined in the whitepaper. A user bonds LUSD, and accrues an bLUSD balance over time on a smooth sub-linear schedule.

At any time they may **chicken out** and reclaim their entire principal, or **chicken in** and give up their principal in exchange for freshly minted bLUSD.

bLUSD may always be redeemed for a proportional share of the system’s reserve LUSD.

However, LUSD Chicken Bonds contains additional functionality for the purposes of peg stabilization and migration. The funds held by the protocol are split across two yield-bearing vaults, referred to as the **B.AMM SP Vault** (from B.Protocol) and the **Yearn Curve Vault**. The former deposits funds to the Liquity Stability Pool, and the latter deposits funds into the Curve LUSD3CRV MetaPool and then [deposit LP tokens into Convex](https://yearn.finance/#/vault/0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6).

The LUSD Chicken Bonds system has public shifter functions which are callable by anyone and move LUSD between the vaults, subject to Curve spot price constraints. The purpose of these is to allow anyone to tighten the Curve pool’s LUSD spot price dollar peg, by moving system funds between the yield-bearing vaults (and thus to or from the Curve pool).

Additionally, the system contains logic for a “migration mode” which may be triggered only by a single privileged admin - namely the Yearn Finance governance address:
0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52

When Yearn upgrade their vaults from v2 to v3, they will freeze deposits and cease harvesting yield. Migration mode allows the LUSD Chicken Bonds system to wind down gracefully, and allows all funds to be redeemed or withdrawn, so that users, if they so choose, may redeposit their funds to a new LUSD Chicken Bonds version which will be connected up to Yearn’s v3 vault.


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

The bulk of significant testing has been done using a mainnet fork, since ChickenBonds will heavily depend on the deployed B.Protocol, Yearn vault, Curve pool and Convex.

For mainnet fork testing in Foundry, please set the env variable `ETH_RPC_URL` equal to your API key for a Ethereum RPC node service such as Alchemy or Infura. Run all mainnet tests with:
forge test --fork-url $ETH_RPC_URL

Core contracts are found in `src`, and tests are in `src/test/`

## Global Liquidity Buckets

As per the whitepaper, LUSD Chicken Bonds utilizes 3 global LUSD buckets: the **pending** bucket, the **reserve** bucket, and the **permanent** bucket, all of which earn yield.

The **pending** bucket contains the LUSD of all open bonds. It is untouched by redemptions. 

The **permanent** bucket contains all protocol-owned LUSD. It is untouched by redemptions, and remains permanently owned by the protocol in normal mode.

The **reserve** bucket contains all LUSD held by the protocol which may be redeemed by burning bLUSD. 



### Yield sources

The Chicken Bonds system deposits LUSD to external vaults - the B.AMM SP vault, and the Yearn Curve vault -  which generate yield.

All funds held by the system (pending, reserve and permanent) are held inside one of the vaults and generate yield - all of which is added to the reserve bucket.


### Individual Liquidity Buckets

The global **permanent** and **reserve** buckets are split across both B.AMM SP vault and the Curve pool (with its LP tokens deposited to the Yearn Curve vault for yield generation).  

The **pending** bucket is held purely by the B.AMM SP vault.

The buckets are split in the following manner in normal mode:

- Pending LUSD in the B.AMM SP vault (constitutes all pending LUSD)
- Reserve LUSD in the B.AMM SP vault
- Reserve LUSD in Yearn Curve vault
- Permanent LUSD in the B.AMM SP Vault
- Permanent LUSD in Yearn Curve vault

In migration mode, no funds are permanent. The buckets are split in this manner:

- Pending LUSD in the B.AMM SP Vault (constitutes all pending LUSD)
- Reserve LUSD in the B.AMM SP Vault
- Reserve LUSD in Yearn Curve vault

### Example buckets state

![Chicken bond buckets 2 drawio](https://user-images.githubusercontent.com/701095/181210047-91267f00-b0c4-4a9c-bcc6-15dce5c28dba.png)

_This diagram shows an example state of the individual buckets in normal mode.  Exact quantities in each individual **reserve** and **permanent** bucket will vary over time - their sizes depend on the history of shift events and the magnitude and and timing of early chicken-ins._



### Flow of funds between individual buckets

For the global permanent and reserve buckets, the split is updated by shifter functions which move funds between the SP vault and the Curve pool. Here is an outline of how funds flow between buckets due to various system operations:

`createBond:` deposits the bonded LUSD to the B.AMM SP vault pending bucket

`chickenIn (normal mode):`
- Moves some portion of bond’s LUSD from B.AMM SP vault pending bucket to B.AMM SP vault reserve bucket
- Moves the remainder of bond’s LUSD from B.AMM SP vault pending bucket to B.AMM SP vault permanent bucket

`chickenIn (migration mode):`
- Moves some portion of bond’s LUSD from B.AMM SP vault pending bucket to B.AMM SP vault reserve bucket
- Refund the remainder of bond’s LUSD from B.AMM SP vault pending bucket to the caller

`chickenOut:` Withdraws all of the bond’s LUSD from the B.AMM SP vault pending bucket

`redeem(normal mode):` Pulls funds proportionally from the B.AMM SP vault reserve bucket and the Curve reserve bucket (sends yTokens, and does not unwrap to LUSD). Redemptions are disabled until 15 days after the first chicken in.

`redeem(migration mode)`: Pulls redeemed funds proportionally from the B.AMM SP vault reserve bucket (as LUSD) and the Curve reserve bucket (as yTokens)

`shiftLUSDFromSPToCurve`:
- Moves some LUSD from the B.AMM SP vault reserve bucket to the Curve reserve bucket
- Moves some LUSD from the B.AMM SP vault permanent bucket to the Curve permanent bucket

`shiftLUSDFromCurveToSP:`
- Moves some LUSD from Curve reserve bucket to the B.AMM SP vault reserve bucket
- Moves some LUSD from Curve permanent bucket to the B.AMM SP vault permanent bucket


### Tracking individual bucket quantities

The **pending** bucket and individual **permanent** buckets are tracked by state variables in `ChickenBondManager`, and updated when funds are added/removed.  Specifically, these state variables are:

- `pendingLUSD`
- `permanentLUSDInBAMMSPVault`
- `permanentLUSDInYearnCurveVault`

Individual **reserve** buckets are not explicitly tracked via state variables. Rather, the reserve LUSD in a given pool (B.AMM SP vault or Curve) is calculated based on the total funds held in the pool, minus any pending and permanent funds in that pool.  

The following getter functions in the smart contract perform these calculations for individual reserve buckets:
- `getAcquiredLUSDInSP()`
- `getAcquiredLUSDInCurve()`

## The First Chicken In

Special logic applies to the First Chicken In.  A "First Chicken In" is defined as a Chicken In which increases the bLUSD supply from zero to non-zero.  Since redemptions always leave non-zero bLUSD in existence, there can only be one first Chicken In.

The following extra logic applies to the first Chicken In:

- It can only be performed after an initial bootstrap period of 15 days has passed
- All yield that has accumulated in the reserve bucket is sent as rewards to the staking contract for bLUSD-LUSD AMM LPs.
- B.Protocol must hold at least as much LUSD as the reserve bucket. This is to ensure that B.Protocol can fully cover the transfer of the reserve bucket to the staking contract. In most cases it will, though after heavy Liquity liquidations it may take some time for B.Protocol to convert the ETH liquidation gains back to LUSD.  In this case, Chicken Bond bonders will just need to wait until the LUSD in B.Protocol has replenished before a First Chicken In is possible.

The special First Chicken In logic only applies in Normal Mode. In Migration Mode, a First Chicken In is no different from a normal Chicken In.

Subsequent Chicken Ins are not subject to the Chicken In bootstrap period.

## Shifter functions

The two system shifter functions are public and permissionless.  They are: `shiftLUSDFromSPToCurve` and `shiftLUSDFromCurveToSP`.

In principle, when the LUSD spot price in the Curve is > 1, anyone may shift LUSD from the Liquity Stability Pool to the Curve pool (routed via the corresponding B.AMM and Yearn vaults), thus moving the spot price back toward 1 - improving the dollar peg. Conversely, when the spot price is < 1, anyone may shift LUSD from the Curve pool and into the Stability Pool, which increases the price toward 1.

Crucially, an LUSD shift transaction only succeeds if it improves the Curve spot price by bringing it closer to 1. Shifter functions are enabled in normal mode and disabled in migration mode.

### Spot Price Thresholds

In practice, Curve charges fees when single-sided LUSD is deposited or withdrawn.  In order to avoid net losses for the Chicken Bonds system, shifting is restricted by two thresholds on the LUSD-3CRV spot price. Let these price thesholds be `x` and `y` where `x < 1` and `y > 1`.  

- Shifting from Curve to the SP is possible when the spot price is < x, and must not move the spot price above x.  
- Shifting from the SP to Curve is possible when the spot price is > y, and must not move the spot price below y.

<img width="636" alt="image" src="https://user-images.githubusercontent.com/32799176/177153259-e7d4f61c-b26f-4f04-a79c-3d4859fe7014.png">

The exact threshold values have been determined by thorough analysis and simulations, found here:
https://docs.google.com/document/d/1fagBvVWRy9hQjrJvK4daK_F8iT9lfUeUrmlxC56Qzfw/edit#heading=h.19g2nvu3uvq8

The choice of thresholds ensures that shifting LUSD is profitable for the Chicken Bonds system.

### Additional shifter conditions

- **Initial bootstrap period**. Both shifters are disabled for an initial period of 45 days post-launch. As a result, all system funds remain in B.Protocol for this initial period.
- **bLUSD supply must be > 0**. There must be a non-zero supply of bLUSD for shifters to work.  This ensures that all system funds remain deposited in B.Protocol before the first Chicken In.
- **Funds deposited in Curve must never exceed the Permanent bucket size**. This guarantees that the system always offers a yield greater than that earned by a pure B.protocol deposit.

### Shifter countdown period and shifting window

It is not possible to shift funds without first starting a countdown. 

In order to shift funds, someone must first start the countdown via the permissionless `startShifterCountdown` function. The countdown period is set to 1 hour. 

When the countdown period ends, the "shifting window" opens: this period is 10 minutes. During the shifting window, anyone may shift funds (subject to the other shifting conditions).

A new countdown can only be started if the previous countdown period and subsequent shifting window have ended.

#### Purpose of countdown and shifting window

The intent is to minimize the frontrunning of Liquity liquidations by shifts of Chicken Bonds funds.

Shifts are only possible during the shifting window which opens when a countdown has been initiated and completed. 

Since Liquity liquidations can happen at any time, then statistically, even if an attacker kept restarting countdowns as soon as possible, a large proportion of liquidations would not fall within the shifting window and therefore could not be frontrun. Assuming liquidations are randomly distributed in time (since they depend on the Ether price), the tighter the shifting window relative to the countdown period, then the lower the percentage of liquidations that will fall within the window.


## Core smart contract architecture

- `ChickenBondManager:` this contract contains the majority of system logic. It contains public state-changing functionality for bonding, chickening in and out, shifting protocol funds between vaults, and redeeming bLUSD. It also contains several getters for the various bucket quantities.


- `BondNFT:` is the ERC721 which mints bond NFTs upon creation.  A bond NFT entitles the holder to take actions related to the corresponding bond i.e. chickening in or out.


- `BLUSDToken:` the token contract for bLUSD. Standard ERC20 functionality.


## External integrations

LUSD Chicken bonds is connected to three external contracts which are already live on mainnet:

- **B.AMM SP vault**.  Chicken Bonds deposits funds here upon bond creation, to earn yield. This vault utilizes the Liquity Stability Pool (SP), which  generates a return on deposited LUSD, in LUSD.

- **Curve LUSD3CRV MetaPool**. Chicken Bonds deposits LUSD here and receives the LUSD3CRV LP token. This is in turn deposited to the Yearn Curve vault.

- **Yearn Curve vault**. LUSD3CRV is deposited here, and the vault generates a return on the deposit, paid in LUSD3CRV.

ETH and LQTY yield earned in the B.AMM SP vault is converted to LUSD via public AMM swaps, in order to realize the gains in terms of LUSD.

Yearn Curve vault is periodically manually harvested by the Yearn team in order to realize the yield in terms of the deposited token.


## Public state-changing functions

- `createBond(_lusdAmount):` creates a bond for the user and mints a bond NFT to their address. A user may create multiple bonds.

- `chickenOut(bondID, _minLUSD):` removes the given bond from the system and burns the bond NFT. Refunds the bonded LUSD to the caller. Takes a `_minLUSD` parameter which allows the user to specify the minimum LUSD they should receive (useful in case the system temporarily can't send them their full bonded LUSD amount, due to pending yield conversion).

- `chickenIn(bondID):` removes the given bond from the system and burns the bond NFT. Makes a portion of the bonded LUSD “acquired” and redeemable, and the remainder of the bonded LUSD permanently protocol-owned.  The split between these two quantities is determined such that the global system backing ratio remains constant.

- `redeem(_bLUSDAmount, _minLUSDFromBAMMSPVault):` Burns the provided bLUSD, and pulls funds from the system’s reserve LUSD in an amount proportional to the fraction of total bLUSD burned.  Funds are drawn proportionally from the B.AMM SP and Curve vaults and sent to the redeemer. Takes a `_minLUSDFromBAMMSPVault` parameter which allows the user to specify the minimum LUSD that should be redeemed from the B.AMM (useful in case there is temporarily not enough LUSD in the B.AMM SP vault to fulfil a proportional redemption request, and the user simply wants to redeem as much LUSD as possible). Funds coming from the Yearn Curve vault are not unwrapped, so the user would receive yTokens instead of LUSD.  A redemption can not deplete the total bLUSD supply below 1 LUSD.

- `shiftLUSDFromSPToCurve(_maxLUSDToShift):` Shifts up to the given LUSD amount from the B.AMM SP vault to Curve, and deposits the received LP tokens to the Curve vault. Pulls funds from the reserve and permanent buckes in the SP vault, and moves them to the reserve and permanent buckets in the Curve vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `shiftLUSDFromCurveToSP(_maxLUSDToShift):` Shifts up to the given LUSD amount from the Curve to the B.AMM SP vault. Pulls funds from the Curve reserve and permanent buckets, and moves them to the reserve and permanent buckets in the SP vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `sendFeeShare(_lusdAmount):` Callable only by Yearn Governance. Transfers the provided LUSD to the ChickenBondManager contract, and deposits it to the B.AMM SP vault.

- `activateMigration():` Callable only by Yearn Governance. Moves all funds in permanent buckets to their corresponding reserve buckets, thus making all system funds (except for the pending bucket) redeemable.

- `startShifterCountdown()`: Permissionless function that starts a new shifter countdown to a shifting window, if the previous countdown and subsequent shifting window have both ended.

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

In case of deprecation of the Curve LUSD3CRV vault, we'd like to launch a new Chicken Bonds system that is hooked up to v3 vaults, and encourage users to migrate their funds.

We need to ensure that, when Yearn deprecate the v2 vaults, all LUSD can be extracted from the old Chicken Bonds system, via a combination of redemptions and chicken-outs 

A proxy upgrade pattern was briefly considered: it would have been simple to give Yearn control over setting the v3 vault addresses in `ChickenBondManager`, and directly migrating system funds from v2 -> v3 vaults. However, as Chicken Bonds may one day hold hundreds of millions of dollars worth of funds, we deemed this too great a responsibility - it would in theory be possible for a rogue actor with such capability to create fake v3 vault contracts and drain all Chicken Bond system funds. 

For better trust minimization we instead opted for a "wind down" approach where Yearn governance can _prepare_ the system for migration by making all funds redeemable. When suitable v3 vaults are live, we would deploy a fresh instance of LUSD Chicken Bonds connected up to them - and encourage users to manually migrate.

### Migration functionality

The `ChickenBondManager` contract contains a function `activateMigration`, callable one-time and only by Yearn Governance. Yearn have agreed to call this function when they deprecate the v2 vaults that Chicken Bonds is connected to. `activateMigration` does the following:

- Raise a `migration` mode flag
- Move all permanent LUSD from permanent bucket to reserve bucket (thus making it redeemable)

### Post-migration logic

Migration mode activation triggers the following logic changes:

`createBond`: disabled

`shiftLUSDFromSPToCurve`, `shiftLUSDFromCurveToSP`: disabled

`chickenOut`: no changes

`chickenIn`:
- Does not increase the permanent bucket with the LUSD surplus
- Instead, refunds the surplus LUSD to the bonder
- No first-chicken-in yield and no chicken-in fee is sent to AMM rewards. Reasoning: no need to maintain AMM LP incentives in migration mode. It's fine and desirable for LPs to pull funds and redeem their bLUSD.

`redeem`: pulls funds proportionally from the B.AMM SP reserve bucket (as LUSD) and the Curve reserve bucket (as yTokens for the Yearn Curve vault)

## Fee share functionality

We will participate in Yearn's partnership program whereby they send a share of the vault fees back to the Chicken Bonds system:
https://docs.yearn.finance/partners/introduction

_"any protocol that integrates yVaults can earn up to a 50% profit share from their contributed TVL."_

We assume they will send us the fee share in LUSD from the Yearn governance address. `ChickenBondManager` has a `sendFeeShare` function, callable only by them, which transfers the LUSD and deposits it to the B.AMM SP vault in normal mode. It's disabled in migration mode, since harvests/fees will not occur.

## Creating a bond from a Gnosis Safe

Most Chicken Bonds front ends utilize the LUSD `permit` functionality for approvals. This historically does not play well with Gnosis Safe.

If you want to create an LUSD bond from your Gnosis safe multi-sig, we recommend you use a standard two-transaction approval pattern. Please follow these steps in the Gnosis Safe UI:

**1. Approve Chicken Bonds to use your LUSD** 
- In Gnosis Safe, goto "New transaction" -> "Contract interaction"
- Input the LUSD contract address: 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0
- Choose the `approve` function from the dropdown list
- In the `spender` field, input the ChickenBondManager contract address: 0x57619FE9C539f890b19c61812226F9703ce37137
- In the `amount` field, input the amount with 18 zeros on the end. e.g. to approve 1234 LUSD, enter `1234000000000000000000`
- Submit, sign and execute the transaction in Gnosis Safe

**2. Create a bond with your LUSD**
- In Gnosis Safe, goto "New transaction" -> "Contract interaction"
- Input the ChickenBondManager contract address: 0x57619FE9C539f890b19c61812226F9703ce37137
- Choose the `createBond` function from the dropdown list
- In the `_lusdAmount` field, enter the amount with 18 zeros on the end, e.g. to bond 1234 LUSD, enter `1234000000000000000000`
- Submit, sign and execute the transaction in Gnosis Safe
