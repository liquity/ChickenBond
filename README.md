# ChickenBond

Research and development

## LUSD Chicken Bonds - Technical Readme

LUSD Chicken bonds is a specific implementation of the General Chicken Bonds model described in the whitepaper.

The system has two goals: 

- To acquire permanent protocol-owned liquidity by offering a boosted yield on deposited LUSD
- To stabilize the LUSD dollar peg on the Curve.fi LUSD-3CRV metapool (the venue where the majority of LUSD trading volume has historically occurred).

## Overview of mechanics

The core mechanics remain the same as outlined in the whitepaper. A user bonds LUSD, and accrues an sLUSD balance over time on a smooth sub-linear schedule.

At any time they may **chicken out** and reclaim their entire principle, or **chicken in** and give up their principal in exchange for freshly minted sLUSD.

sLUSD may always be redeemed for a proportional share of the system’s acquired LUSD.

However, LUSD Chicken Bonds contains additional functionality for the purposes of peg stabilization and migration. The funds held by the protocol are split across two yield-bearing Yearn vaults, referred to as the **Yearn SP Vault** and the **Yearn Curve Vault**. The former deposits funds to the Liquity Stability Pool, and the latter deposits funds into the Curve LUSD3CRV MetaPool.

The LUSD Chicken Bonds system has public shifter functions which are callable by anyone and move LUSD between the vaults, subject to price constraints. The purpose of these is to allow anyone to tighten the Curve pool’s LUSD spot price dollar peg, by moving system funds between the yield-bearing vaults (and thus to or from the Curve pool).

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
- LUSDChickenBonds/src/utils` - Contains basic math and logging utilities used in the core smart contracts.

## Running the project

ChickenBonds is a Foundry project in `/LUSDChickenBonds`.  

Install Foundry:
https://github.com/gakonst/foundry
Run all with `forge test`.

For mainnet fork testing, please set the env variable `ETH_RPC_URL` equal to your API key for a Ethereum RPC node service such as Alchemy or Infura.

Core contracts are found in `src`, and tests are in `src/test`/

## Global Liquidity Buckets

As per the whitepaper, LUSD Chicken Bonds utilizes 3 global LUSD buckets: the **pending** bucket, the **acquired** bucket, and the **permanent** bucket, all of which earn yield.

The **pending** bucket contains the LUSD of all open bonds. It is untouched by redemptions. 

The **permanent** bucket contains all protocol-owned LUSD. It is untouched by redemptions, and remains permanently owned by the protocol in normal mode.

The **acquired** bucket contains all LUSD held by the protocol which may be redeemed by burning sLUSD. 

### Yield sources

The Chicken Bonds system deposits LUSD to external Yearn vaults - the Yearn SP vault, and the Yearn Curve vault -  which generate yield.

All funds held by the system (pending, acquired and permanent) are held inside one of the vaults and generate yield - all of which is added to the acquired bucket.


### Individual Liquidity Buckets

The global **permanent** and **acquired** buckets are split across both Yearn SP and the Curve pool (with its LP tokens deposited to the Yearn Curve vault for yield generation).  

The **pending** bucket is held purely by the Yearn SP vault in normal mode, and purely by the LUSD Silo in migration mode.

The buckets are split into in the following manner normal mode:

- Pending LUSD in the Yearn SP vault (constitutes all pending LUSD)
- Permanent LUSD in the Yearn SP Vault
- Permanent LUSD in Curve
- Acquired LUSD in the Yearn SP vault
- Acquired LUSD in Curve

In migration mode, no funds are permanent. The buckets are split in this manner:

- Pending LUSD in the LUSD Silo
- Acquired LUSD in the LUSD Silo
- Acquired LUSD in Curve

### Flow of funds between individual buckets

For the global permanent and acquired buckets, the split is updated by shifter functions which move funds between the SP vault and the Curve pool. Here is an outline of how funds flow between buckets from various system operations:

`createBond:` deposits the bonded LUSD to the Yearn SP vault pending bucket

`chickenIn (normal mode):`
- Moves some portion of bond’s LUSD from Yearn SP vault pending bucket to Yearn SP vault acquired bucket
- Moves the remainder of bond’s LUSD from Yearn SP vault pending bucket to Yearn SP vault permanent bucket

`chickenIn (migration mode):`
- Moves some portion of bond’s LUSD from the LUSD Silo pending bucket to Yearn SP vault acquired bucket
- Refund the remainder of bond’s LUSD from LUSD Silo pending bucket to the caller

`chickenOut (normal mode):` Withdraws all of the bond’s LUSD from the Yearn SP vault pending bucket

`chickenOut (normal mode):` Withdraws all of the bond’s LUSD from the LUSD Silo pending bucket

`redeem(normal mode):` Pulls funds proportionally from the Yearn SP vault acquired bucket and the Curve acquired bucket (sends yTokens, and does not unwrap to LUSD)

`redeem(migration mode)`: Pulls redeemed funds proportionally from the LUSD Silo acquired bucket (as LUSD) and the Curve acquired bucket (as yTokens)

`shiftLUSDFromSPToCurve`:
- Moves some acquired LUSD from the Yearn SP vault acquired bucket to the Curve acquired bucket
- Moves some permanent LUSD from the Yearn SP vault permanent bucket to the Curve permanent bucket

`shiftLUSDFromCurveToSP:`
- Moves acquired LUSD in Curve to the Yearn SP vault acquired bucket
- Moves permanent LUSD in Curve to the Yearn SP vault permanent bucket


### Tracking individual bucket quantities

The pending bucket and individual permanent buckets are tracked by state variables in `ChickenBondManager`, and updated when funds are added/removed.  Specifically, they are:

- `totalPendingLUSD`
- `permanentLUSDInYearnSPVault`
- `permanentLUSDInYearnCurveVault`

Individual acquired buckets are not explicitly tracked via state variables. Rather, the acquired LUSD in a given pool (Yearn SP or Curve) is calculated based on the total funds held in the pool, minus any pending or permanent funds in that pool.  

The following getter functions in the smart contract perform these calculations for individual acquired buckets:
- `getAcquiredLUSDInSPVault()`
- `getAcquiredLUSDInCurve()`
- `getAcquiredLUSDInLUSDSilo()`


## Shifter functions

The two system shifter functions are public and permissionless.  They are: `shiftLUSDFromSPToCurve` and `shiftLUSDFromCurveToSP`.

When the LUSD spot price in the Curve is > 1, anyone may shift LUSD from the Liquity Stability Pool to the Curve pool (routed via the corresponding Yearn vaults), thus moving the spot price back toward 1 - improving the dollar peg. Conversely, when the spot price is < 1, anyone may shift LUSD from the Curve pool and into the Stability Pool, which increases the price toward 1.

Crucially, an LUSD shift transaction only succeeds if it improves the Curve spot price by bringing it closer to 1 - yet, must not cause it to cross the boundary of 1. Shifter functions are enabled in normal mode and disabled in migration mode.


## Core smart contract architecture

- `ChickenBondManager:` this contract contains the majority of system logic. It contains public state-changing functionality for bonding, chickening in and out, shifting protocol funds between vaults, and redeeming sLUSD. It also contains several getters for the various bucket quantities.


- `BondNFT:` is the ERC721 which mints bond NFTs upon creation.  A bond NFT entitles the holder to take actions related to the corresponding bond i.e. chickening in or out.


-`LUSDSilo:` is a simple container contract that is only utilized in migration mode. Upon migration, it receives all of the system funds that were previously held in the SP vault. 

- `SLUSDToken:` the token contract for sLUSD. Standard ERC20 functionality.


## External integrations

LUSD Chicken bonds is connected to three external contracts which are already live on mainnet:

- Yearn LUSD Vault.  ChickenBonds deposits funds here upon bond creation to earn yield.  This vault utilizes the Liquity Stability Pool and the Tokemak LUSD reactor, which generate a return on deposited LUSD, in LUSD. 

- Curve LUSD3CRV metapool.  Chicken Bonds deposits LUSD here and receives the LUSD3CRV LP token.  This is in turn deposited to the Yearn Curve vault which generates a return on deposited LUSD3CRV, in LUSD3CRV.

- Yearn Curve Vault. LUSD3CRV is deposited here, and the vault generates a return on the deposit, paid in LUSD3CRV.

Each Yearn vault is periodically manually harvested by the Yearn team in order to realize the yield in terms of the deposited token.


## Public state-changing functions

- `createBond(_lusdAmount):` creates a bond for the user and mints a bond NFT to their address. A user may create multiple bonds.

- `chickenOut(bondID):` removes the given bond from the system and burns the bond NFT. Refunds the bonded LUSD to the caller.

- `chickenIn(bondID):` removes the given bond from the system and burns the bond NFT. Makes a portion of the bonded LUSD “acquired” and redeemable, and the remainder of the bonded LUSD permanently protocol-owned.  The split between these two quantities is determined such that the global system backing ratio remains constant.

- `redeem(_sLUSDAmount):` Burns the provided sLUSD, and pulls funds from the system’s acquired LUSD in an amount proportional to the fraction of total sLUSD burned.  Funds are drawn proportionally from the Yearn SP and Curve vaults and sent to the redeemer.


- `shiftLUSDFromSPToCurve(_lusdAmount):` Shifts the given LUSD amount from the Yearn SP vault to Curve, and deposits the received LP tokens to the Curve vault. Pulls funds from the acquired and permanent buckes in the SP vault, and moves them to the acquired and permanent buckets in the Curve vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `shiftLUSDFromCurveToSP(_lusdAmount):` Shifts the given LUSD amount from the Curve to the Yearn SP vault. Pulls funds from the Curve acquired and permanent buckets, and moves them to the acquired and permanent buckets in the SP vault, respectively. Only succeeds if the shift improves the LUSD peg.

- `sendFeeShare(_lusdAmount):` Callable only by Yearn Governance. Transfers the provided LUSD to the ChickenBondManager contract, and deposits it to the Yearn SP Vault.

- `activateMigration():` Callable only by Yearn Governance. Pulls all funds from the Yearn SP vault and transfers them to a trusted Silo contract. Moves all funds in permanent buckets to their corresponding acquired buckets, thus making all system funds (except for the pending bucket) redeemable.

## Controller
TODO (grab from PR)

## Migration mode
TODO (grab from PR)





