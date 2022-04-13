# ChickenBond

Research and development

# LUSD ChickenBonds

## Running the project


ChickenBonds is a Foundry project in `/LUSDChickenBonds`.  

Install Foundry:
https://github.com/gakonst/foundry
Run tests with `forge test`.

Core contracts are found in `src`.

## TODO List

### Initialization

- [ ] 50:50 split upon the very first chicken-in to initialize the bTKN/TKN pool. 
- [ ] Market price = redemption price = 1
- [ ] Forbid chicken-ins during 1 week (tbd)
- [ ] Forbid redemptions during 1 month (tbd)

### Base functionality
- [x] BondNFT 
- [x] sLUSDToken
- [x] mock Curve pool
- [x] mock Yearn LUSD and Curve vaults
- [x] createBond
- [x] chickenIn 
- [x] chickenOut
- [x] redeem 
- [x] Change accrual function to asymptotic curve, remove cap constraint
- [x] refund functionality inside chickenIn
- [x] Shifting functions
- [ ] **Replace refund functionality with permanent bucket**
- [ ] **Liquity-like redemption fee**
- [x] Extract common functionality in core contracts 
- [x] Extract common setup functionality in unit tests
- [ ] Basic math function for converting to/from 18 digit fractions
- [ ] Implement main events
- [ ] Settle on best Solidity version to use (OZ contracts are v8+, and Slither detects v8+)
- [ ] Add return values to all state-changing functions for integrations
- [ ] Tax on chicken in + incentive for bTKN/TKN pool
- [x] Adapt shifting function: revert when Curve price crosses boundary 

### External contracts integrations 
- [x] Determine most accurate way to compute `totalAccruedLUSD` from Yearn and Curve
- [x] Determine Curve trade quantity calculation for shifting functions (we simply revert if the price crosses the $1.0 boundary)
- [x] Implement Yearn Registry check for latest vaults  and migration functionality
- [x] Connect to real Yearn and Curve contracts
- [x] Mainnet hard fork testing  

### Security
- [ ] Create thorough unit test plan: negative tests, multiple bonds per user, etc. 
- [ ] **Create list of system properties/invariants and add `asserts`**
- [ ] **More extensive testing for edge cases (e.g. pending harvests, harvest losses, external calls to Yearn/Curve reverting, etc)**
- [ ] Run Slither / MythX
- [ ] **Systemic fuzzing** (Dani?)

### Design 
- [ ] **Determine redemption fee formula **
- [ ] **Determine sLUSD accrual function  / controller**
- [ ] Decide on NFT enumeration (i.e. getting all of a user's bonds), and/or extra trade functionality





