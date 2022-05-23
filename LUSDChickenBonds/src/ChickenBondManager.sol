// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./utils/ChickenMath.sol";

import "./Interfaces/IBondNFT.sol";
//import "./utils/console.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ISLUSDToken.sol";
import "./Interfaces/IYearnVault.sol";
import "./Interfaces/ICurvePool.sol";
import "./Interfaces/IYearnRegistry.sol";
import "./LPRewards/Interfaces/IUnipool.sol";


contract ChickenBondManager is Ownable, ChickenMath {

    // ChickenBonds contracts
    IBondNFT immutable public bondNFT;

    ISLUSDToken immutable public sLUSDToken;
    ILUSDToken immutable public lusdToken;

    // External contracts
    ICurvePool immutable public curvePool;
    IYearnVault immutable public yearnLUSDVault;
    IYearnVault immutable public yearnCurveVault;
    IYearnRegistry immutable public yearnRegistry;
    IUnipool immutable public sLUSDLPRewardsStaking;

    uint256 immutable public CHICKEN_IN_AMM_TAX;

    uint256 private permanentLUSD;

    // --- Data structures ---

    struct ExternalAdresses {
        address bondNFTAddress;
        address lusdTokenAddress;
        address curvePoolAddress;
        address yearnLUSDVaultAddress;
        address yearnCurveVaultAddress;
        address sLUSDTokenAddress;
        address yearnRegistryAddress;
        address sLUSDLPRewardsStakingAddress;
    }
    
    /* Used to hold, return and assign variables inside the redeem() function, in order to avoid the error:
    "CompilerError: Stack too deep". */
    struct LocalVarsRedemption {
        uint256 fractionOfSLUSDToRedeem;
        uint256 redemptionFeePercentage;
        uint256 fractionOfAcquiredLUSDToWithdraw;
        uint256 lusdInYearn;
        uint256 lusd3CRVInCurve;
        uint256 lusdToWithdrawFromYearn;
        uint256 yTokensToWithdrawFromLUSDVault;
        uint256 yTokensAcquiredCurveVault;
        uint256 yTokensToWithdrawFromCurveVault;
        uint256 lusdBalanceBefore;
        uint256 LUSD3CRVBalanceBefore;
        uint256 LUSD3CRVDelta;
        uint256 lusdBalanceDelta;
    }

    struct BondData {
        uint256 lusdAmount;
        uint256 startTime;
    }

    uint256 public totalPendingLUSD;
    uint256 public totalWeightedStartTimes; // Sum of `lusdAmount * startTime` for all outstanding bonds (used to tell weighted average bond age)
    uint256 public lastRedemptionTime; // The timestamp of the latest redemption
    uint256 public baseRedemptionRate; // The latest base redemption rate
    mapping (uint256 => BondData) public idToBondData;

    // constants
    uint256 constant MAX_UINT256 = type(uint256).max;
    int128 constant INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = 0;
    int128 constant INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL = 1;

    uint256 constant public SECONDS_IN_ONE_MINUTE = 60;
    /*
     * BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
     * Corresponds to (1 / ALPHA) in the Liquity white paper.
     */
    uint256 constant public BETA = 2;
    /*
     * TODO:
     * Half-life of 12h. 12h = 720 min
     * (1/2) = d^720 => d = (1/2)^(1/720)
     */
    uint256 constant public MINUTE_DECAY_FACTOR = 999037758833783000;

    // --- Accrual control variables ---

    // `block.timestamp` of the block in which this contract was deployed.
    uint256 public immutable deploymentTimestamp;

    // Average outstanding bond age above which the controller will adjust `accrualParameter` in order to speed up accrual.
    uint256 public immutable targetAverageAgeSeconds;

    // Stop adjusting `accrualParameter` when this value is reached.
    uint256 public immutable minimumAccrualParameter;

    // Number between 0 and 1. `accrualParameter` is multiplied by this every time there's an adjustment.
    uint256 public immutable accrualAdjustmentMultiplier;

    // The duration of an adjustment period in seconds. The controller performs at most one adjustment per every period.
    uint256 public immutable accrualAdjustmentPeriodSeconds;

    // The number of seconds it takes to accrue 50% of the cap, represented as an 18 digit fixed-point number.
    uint256 public accrualParameter;

    // Counts the number of adjustment periods since deployment.
    // Updated by operations that change the average outstanding bond age (createBond, chickenIn, chickenOut).
    // Used by `_calcUpdatedAccrualParameter` to tell whether it's time to perform adjustments, and if so, how many times
    // (in case the time elapsed since the last adjustment is more than one adjustment period).
    uint256 public accrualAdjustmentPeriodCount;

    // --- events ---

    event BaseRedemptionRateUpdated(uint256 _baseRedemptionRate);
    event LastRedemptionTimeUpdated(uint256 _lastRedemptionFeeOpTime);

    // --- constructor ---

    constructor
    (
        ExternalAdresses memory _externalContractAddresses, // to avoid stack too deep issues
        uint256 _targetAverageAgeSeconds,
        uint256 _initialAccrualParameter,
        uint256 _minimumAccrualParameter,
        uint256 _accrualAdjustmentRate,
        uint256 _accrualAdjustmentPeriodSeconds,
        uint256 _CHICKEN_IN_AMM_TAX
    )
    {
        bondNFT = IBondNFT(_externalContractAddresses.bondNFTAddress);
        lusdToken = ILUSDToken(_externalContractAddresses.lusdTokenAddress);
        sLUSDToken = ISLUSDToken(_externalContractAddresses.sLUSDTokenAddress);
        curvePool = ICurvePool(_externalContractAddresses.curvePoolAddress);
        yearnLUSDVault = IYearnVault(_externalContractAddresses.yearnLUSDVaultAddress);
        yearnCurveVault = IYearnVault(_externalContractAddresses.yearnCurveVaultAddress);
        yearnRegistry = IYearnRegistry(_externalContractAddresses.yearnRegistryAddress);

        deploymentTimestamp = block.timestamp;
        targetAverageAgeSeconds = _targetAverageAgeSeconds;
        accrualParameter = _initialAccrualParameter;
        minimumAccrualParameter = _minimumAccrualParameter;
        accrualAdjustmentMultiplier = 1e18 - _accrualAdjustmentRate;
        accrualAdjustmentPeriodSeconds = _accrualAdjustmentPeriodSeconds;

        sLUSDLPRewardsStaking = IUnipool(_externalContractAddresses.sLUSDLPRewardsStakingAddress);
        CHICKEN_IN_AMM_TAX = _CHICKEN_IN_AMM_TAX;

        // TODO: Decide between one-time infinite LUSD approval to Yearn and Curve (lower gas cost per user tx, less secure
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lusdToken.approve(address(yearnLUSDVault), MAX_UINT256);
        lusdToken.approve(address(curvePool), MAX_UINT256);
        curvePool.approve(address(yearnCurveVault), MAX_UINT256);
        lusdToken.approve(address(sLUSDLPRewardsStaking), MAX_UINT256);

        // Check that the system is hooked up to the correct latest Yearn vaults
        assert(address(yearnLUSDVault) == yearnRegistry.latestVault(address(lusdToken)));
        // TODO: Check mainnet registry for the deployed Yearn Curve vault
        // assert(address(yearnCurveVault) == yearnRegistry.latestVault(address(curvePool)));

        renounceOwnership();
    }

    // --- User-facing functions ---

    function createBond(uint256 _lusdAmount) external {
        _requireNonZeroAmount(_lusdAmount);

        _updateAccrualParameter();

        // Mint the bond NFT to the caller and get the bond ID
        uint256 bondID = bondNFT.mint(msg.sender);

        //Record the user’s bond data: bond_amount and start_time
        BondData memory bondData;
        bondData.lusdAmount = _lusdAmount;
        bondData.startTime = block.timestamp;
        idToBondData[bondID] = bondData;

        totalPendingLUSD += _lusdAmount;
        totalWeightedStartTimes += _lusdAmount * block.timestamp;

        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        // Deposit the LUSD to the Yearn LUSD vault
        yearnLUSDVault.deposit(_lusdAmount);
    }

    /* NOTE: chickenOut and chickenIn require the caller to pass their correct _bondID. This can be gleaned from their past
    * emitted createBond event.
    * TODO: Decide if we want on-chain functionality for returning a list of a given bonder's NFTs. Increases minting gas cost.
    */

    function chickenOut(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];

        delete idToBondData[_bondID];
        totalPendingLUSD -= bond.lusdAmount;
        totalWeightedStartTimes -= bond.lusdAmount * bond.startTime;

        /* In practice, there could be edge cases where the totalPendingLUSD is not fully backed:
        * - Heavy liquidations, and before yield has been converted
        * - Heavy loss-making liquidations, i.e. at <100% CR
        * - SP or Yearn vault hack that drains LUSD
        *
        * TODO: decide how to handle chickenOuts if/when the recorded totalPendingLUSD is not fully backed by actual
        * LUSD in Yearn / the SP. */

        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        /* Occasionally (e.g. when the system contains only one bonder) the withdrawable LUSD in Yearn 
        * will be less than the bonded LUSD due to rounding error in the share calculation. Therefore,
        * withdraw the lesser of the two quantities. */
        uint256 lusdToWithdraw = Math.min(bond.lusdAmount, lusdInYearn);

        uint256 yTokensToSwapForLUSD = calcCorrespondingYTokens(yearnLUSDVault, lusdToWithdraw, lusdInYearn);

        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnLUSDVault.withdraw(yTokensToSwapForLUSD);
        uint256 lusdBalanceAfter = lusdToken.balanceOf(address(this));

        uint256 lusdBalanceDelta = lusdBalanceAfter - lusdBalanceBefore;

        /* Transfer the LUSD balance delta resulting from the Yearn withdrawal, rather than the ideal bondedLUSD.
        * Reasoning: the LUSD balance delta can be slightly lower than the bondedLUSD due to floor division in the
        * yToken calculation prior to withdrawal. */
        lusdToken.transfer(msg.sender, lusdBalanceDelta);

        bondNFT.burn(_bondID);
    }

    // transfer _yTokensToSwap to the LUSD/sLUSD AMM LP Rewards staking contract
    function _transferToRewardsStakingContract(uint256 _yTokensToSwap) internal {
        // Pull the tax amount from Yearn LUSD vault
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnLUSDVault.withdraw(_yTokensToSwap);

        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
        if (lusdBalanceDelta == 0) { return; }

        /* Transfer the LUSD balance delta resulting from the Yearn withdrawal, rather than the ideal lusdToRefund.
         * Reasoning: the LUSD balance delta can be slightly lower than the lusdToRefund due to floor division in the
         * yToken calculation prior to withdrawal. */
        lusdBalanceBefore = lusdToken.balanceOf(address(this));
        sLUSDLPRewardsStaking.pullRewardAmount(lusdBalanceDelta);
        assert(lusdBalanceBefore - lusdToken.balanceOf(address(this)) == lusdBalanceDelta);
    }

    // Divert acquired yield to LUSD/sLUSD AMM LP rewards staking contract
    // It happens on the very first chicken in event of the system, or any time that redemptions deplete sLUSD total supply to zero
    function _firstChickenIn() internal {
        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        uint256 lusdFromInitialYield = _getTotalAcquiredLUSD(lusdInYearn);
        if (lusdFromInitialYield == 0) { return; }

        uint256 yTokensToSwapForYieldLUSD = calcCorrespondingYTokens(yearnLUSDVault, lusdFromInitialYield, lusdInYearn);
        if (yTokensToSwapForYieldLUSD == 0) { return; }
        _transferToRewardsStakingContract(yTokensToSwapForYieldLUSD);
    }

    function chickenIn(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        uint256 updatedAccrualParameter = _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];
        (uint256 taxAmount, uint256 taxedBondAmount) = _getTaxedBond(bond.lusdAmount);

        if (sLUSDToken.totalSupply() == 0) {
            _firstChickenIn();
        }

        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        uint256 backingRatio = _calcSystemBackingRatio(lusdInYearn);
        uint256 accruedSLUSD = _calcAccruedSLUSD(bond.startTime, taxedBondAmount, backingRatio, updatedAccrualParameter);
        IYearnVault yearnLUSDVaultCached = yearnLUSDVault;

        delete idToBondData[_bondID];

        // Subtract the bonded amount from the total pending LUSD (and implicitly increase the total acquired LUSD)
        totalPendingLUSD -= bond.lusdAmount;
        totalWeightedStartTimes -= bond.lusdAmount * bond.startTime;

        /* Get LUSD amounts to acquire and make permanent. Acquire LUSD in proportion to the system's current backing ratio,
        * in order to maintain said ratio. */
        uint256 lusdToAcquire = accruedSLUSD * backingRatio / 1e18;
        uint256 lusdToPermanent = taxedBondAmount - lusdToAcquire;

        assert ((lusdToAcquire + lusdToPermanent) <= taxedBondAmount);

        uint256 yTokensToSwapForTaxLUSD = calcCorrespondingYTokens(yearnLUSDVaultCached, taxAmount, lusdInYearn);

        // Record the LUSD that correspond to the permanent portion from this chicken-in. This implicitly decreases the acquired LUSD.
        permanentLUSD += lusdToPermanent;
    
        sLUSDToken.mint(msg.sender, accruedSLUSD);
        bondNFT.burn(_bondID);

        // transfer the chicken in tax to the LUSD/sLUSD AMM LP Rewards staking contract
        _transferToRewardsStakingContract(yTokensToSwapForTaxLUSD);
    }

    // TODO: Refactor with new logic
    function redeem(uint256 _sLUSDToRedeem) external {
        _requireNonZeroAmount(_sLUSDToRedeem);

        LocalVarsRedemption memory vars; 
        
        /* TODO: determine whether we should simply leave the fee in the acquired bucket, or add it to a permanent bucket.
        Current approach leaves redemption fees in the acquired bucket. */
        vars.fractionOfSLUSDToRedeem = _sLUSDToRedeem * 1e18 / sLUSDToken.totalSupply();
        // Calculate redemption fraction to withdraw, given that we leave the fee inside the system
        vars.redemptionFeePercentage = calcRedemptionFeePercentage();
        vars.fractionOfAcquiredLUSDToWithdraw = vars.fractionOfSLUSDToRedeem * (1e18 - vars.redemptionFeePercentage) / 1e18;
        // Increase redemption base rate with the new redeemed amount
        _updateRedemptionRateAndTime(vars.redemptionFeePercentage, vars.fractionOfSLUSDToRedeem);

        // Get the LUSD to withdraw from Yearn LUSD Vault, and the corresponding yTokens
        vars.lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        vars.lusd3CRVInCurve = calcTotalYearnCurveVaultShareValue();

        vars.lusdToWithdrawFromYearn = _getAcquiredLUSDInYearn(vars.lusdInYearn) * vars.fractionOfAcquiredLUSDToWithdraw / 1e18;
        vars.yTokensToWithdrawFromLUSDVault = calcCorrespondingYTokens(yearnLUSDVault, vars.lusdToWithdrawFromYearn, vars.lusdInYearn);
        
        //  Since 100% of the Curve vault liquidity is "acquired + permanent", just get the acquired yTokens by subtracting permanent
        if (vars.lusd3CRVInCurve > 0) {
            uint256 yearnCurveVaultBalance = yearnCurveVault.balanceOf(address(this));
            uint256 yTokensPermanentCurveVault = getPermanentLUSDInCurve() * yearnCurveVaultBalance / vars.lusd3CRVInCurve;
            vars.yTokensAcquiredCurveVault = yearnCurveVaultBalance - yTokensPermanentCurveVault;
            vars.yTokensToWithdrawFromCurveVault = vars.yTokensAcquiredCurveVault * vars.fractionOfAcquiredLUSDToWithdraw / 1e18;
        }

        // The LUSD deltas from SP/Curve withdrawals are the amounts to send to the redeemer
        vars.lusdBalanceBefore = lusdToken.balanceOf(address(this));
        vars.LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));
     
        // Redemptions draw LUSD purely from the acquired bucket
        if (vars.yTokensToWithdrawFromLUSDVault > 0) {yearnLUSDVault.withdraw(vars.yTokensToWithdrawFromLUSDVault);} // obtain LUSD from Yearn
        if (vars.yTokensToWithdrawFromCurveVault > 0) {yearnCurveVault.withdraw(vars.yTokensToWithdrawFromCurveVault);} // obtain LUSD3CRV from Yearn
     
        vars.LUSD3CRVDelta = curvePool.balanceOf(address(this)) - vars.LUSD3CRVBalanceBefore;
        if (vars.LUSD3CRVDelta > 0) {curvePool.remove_liquidity_one_coin(vars.LUSD3CRVDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);} // obtain LUSD from Curve
    
        vars.lusdBalanceDelta = lusdToken.balanceOf(address(this)) - vars.lusdBalanceBefore;
    
        _requireNonZeroAmount(vars.lusdBalanceDelta);

        // Burn the redeemed sLUSD
        sLUSDToken.burn(msg.sender, _sLUSDToRedeem);

        // Send the LUSD to the redeemer
        lusdToken.transfer(msg.sender, vars.lusdBalanceDelta);
    }

    function shiftLUSDFromSPToCurve(uint256 _lusdToShift) external {
        _requireNonZeroAmount(_lusdToShift);

        uint256 initialCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(initialCurveSpotPrice > 1e18, "CBM: Curve spot must be > 1.0 before SP->Curve shift");

        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();

        // Convert yTokens to LUSD
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint256 yTokensToBurnFromLUSDVault = calcCorrespondingYTokens(yearnLUSDVault, _lusdToShift, lusdInYearn);
        yearnLUSDVault.withdraw(yTokensToBurnFromLUSDVault);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Curve in return for LUSD3CRV-f tokens
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LP tokens to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.add_liquidity([lusdBalanceDelta, 0], 0);
        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // Deposit the received LUSD3CRV-f to Yearn Curve vault
        yearnCurveVault.deposit(LUSD3CRVBalanceDelta);

        // Ensure the SP->Curve shift has decreased the Curve spot price to not less than 1.0
        uint256 finalCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(finalCurveSpotPrice < initialCurveSpotPrice && finalCurveSpotPrice >=  1e18, "CBM: SP->Curve shift must decrease spot price to >= 1.0");
    }

    function shiftLUSDFromCurveToSP(uint256 _lusdToShift) external {
        _requireNonZeroAmount(_lusdToShift);

        uint256 initialCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(initialCurveSpotPrice < 1e18, "CBM: Curve spot must be < 1.0 before Curve->SP shift");

        //Calculate LUSD3CRV-f needed to withdraw LUSD from Curve
        uint256 LUSD3CRVfToBurn = curvePool.calc_token_amount([_lusdToShift, 0], false);

        //Calculate yTokens to swap for LUSD3CRV-f
        (uint256 LUSD3CRVfInYearn, uint256 lusdInCurveVault) = getTotalLPAndLUSDInCurve();

        // Convert yTokens to LUSD3CRV-f
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));

        uint256 yTokensToBurnFromCurveVault = calcCorrespondingYTokens(yearnCurveVault, LUSD3CRVfToBurn, LUSD3CRVfInYearn);
        yearnCurveVault.withdraw(yTokensToBurnFromCurveVault);
        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(LUSD3CRVBalanceDelta == LUSD3CRVfToBurn);

        // Withdraw LUSD from Curve
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LUSD to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Yearn LUSD vault
        yearnLUSDVault.deposit(lusdBalanceDelta);

        // Ensure the Curve->SP shift has increased the Curve spot price to not more than 1.0
        uint256 finalCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(finalCurveSpotPrice > initialCurveSpotPrice && finalCurveSpotPrice <=  1e18, "CBM: Curve->SP shift must increase spot price to <= 1.0");
    }

    // --- Helper functions ---

    function _getCurveLUSDSpotPrice() public view returns (uint256) {
        // Get the Curve spot price of LUSD: the amount of 3CRV that would be received by swapping 1 LUSD
        return curvePool.get_dy_underlying(INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL, 1e18);
    }

    // Update the base redemption rate and the last redemption time (only if time passed >= decay interval. This prevents base rate griefing)
    function _updateRedemptionRateAndTime(uint256 _decayedBaseRedemptionRate, uint256 _fractionOfSLUSDToRedeem) internal {
        // Update the baseRate state variable
        uint256 newBaseRedemptionRate = _decayedBaseRedemptionRate + _fractionOfSLUSDToRedeem / BETA;
        newBaseRedemptionRate = Math.min(newBaseRedemptionRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%
        //assert(newBaseRedemptionRate <= DECIMAL_PRECISION); // This is already enforced in the line above
        baseRedemptionRate = newBaseRedemptionRate;
        emit BaseRedemptionRateUpdated(newBaseRedemptionRate);

        uint256 timePassed = block.timestamp - lastRedemptionTime;

        if (timePassed >= SECONDS_IN_ONE_MINUTE) {
            lastRedemptionTime = block.timestamp;
            emit LastRedemptionTimeUpdated(block.timestamp);
        }
    }

    // Calc decayed redemption rate
    function calcRedemptionFeePercentage() public view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastRedemption();
        uint256 decayFactor = decPow(MINUTE_DECAY_FACTOR, minutesPassed);

        return baseRedemptionRate * decayFactor / DECIMAL_PRECISION;
    }

    function _minutesPassedSinceLastRedemption() internal view returns (uint256) {
        return (block.timestamp - lastRedemptionTime) / SECONDS_IN_ONE_MINUTE;
    }

    function _getTaxedBond(uint256 _bondLUSDAmount) internal view returns (uint256, uint256) {
        uint256 taxAmount = _bondLUSDAmount * CHICKEN_IN_AMM_TAX / 1e18;
        uint256 taxedBondAmount = _bondLUSDAmount - taxAmount;
        return (taxAmount, taxedBondAmount);
    }

    function _getTaxedBondAmount(uint256 _bondLUSDAmount) internal view returns (uint256) {
        (, uint256 taxedBondAmount) = _getTaxedBond(_bondLUSDAmount);
        return taxedBondAmount;
    }

    // Internal getter for calculating accrued LUSD based on BondData struct
    function _calcAccruedSLUSD(uint256 _startTime, uint256 _lusdAmount, uint256 _backingRatio, uint256 _accrualParameter) internal view returns (uint256) {
        // All bonds have a non-zero creation timestamp, so return accrued sLQTY 0 if the startTime is 0
        if (_startTime == 0) {return 0;}
        uint256 bondSLUSDCap = _calcBondSLUSDCap(_lusdAmount, _backingRatio);

        // Scale `bondDuration` up to an 18 digit fixed-point number.
        // This lets us add it to `accrualParameter`, which is also an 18-digit FP.
        uint256 bondDuration = 1e18 * (block.timestamp - _startTime);

        uint256 accruedSLUSD = bondSLUSDCap * bondDuration / (bondDuration + _accrualParameter);
        assert(accruedSLUSD < bondSLUSDCap);

        return accruedSLUSD;
    }

    // Gauge the average (size-weighted) outstanding bond age and adjust accrual parameter if it's higher than our target.
    // If there's been more than one adjustment period since the last adjustment, perform multiple adjustments retroactively.
    function _calcUpdatedAccrualParameter(
        uint256 _storedAccrualParameter,
        uint256 _storedAccrualAdjustmentCount
    )
        internal
        view
        returns (
            uint256 updatedAccrualParameter,
            uint256 updatedAccrualAdjustmentPeriodCount
        )
    {
        updatedAccrualAdjustmentPeriodCount = (block.timestamp - deploymentTimestamp) / accrualAdjustmentPeriodSeconds;

        if (
            // There hasn't been enough time since the last update to warrant another update
            updatedAccrualAdjustmentPeriodCount == _storedAccrualAdjustmentCount ||
            // or `accrualParameter` is already bottomed-out
            _storedAccrualParameter == minimumAccrualParameter ||
            // or there are no outstanding bonds (avoid division by zero)
            totalPendingLUSD == 0
        ) {
            return (_storedAccrualParameter, updatedAccrualAdjustmentPeriodCount);
        }

        uint256 averageStartTime = totalWeightedStartTimes / totalPendingLUSD;

        // We want to calculate the period when the average age will have reached or exceeded the
        // target average age, to be used later in a check against the actual current period.
        //
        // At any given timestamp `t`, the average age can be calculated as:
        //   averageAge(t) = t - averageStartTime
        //
        // For any period `n`, the average age is evaluated at the following timestamp:
        //   tSample(n) = deploymentTimestamp + n * accrualAdjustmentPeriodSeconds
        //
        // Hence we're looking for the smallest integer `n` such that:
        //   averageAge(tSample(n)) >= targetAverageAgeSeconds
        //
        // If `n` is the smallest integer for which the above inequality stands, then:
        //   averageAge(tSample(n - 1)) < targetAverageAgeSeconds
        //
        // Combining the two inequalities:
        //   averageAge(tSample(n - 1)) < targetAverageAgeSeconds <= averageAge(tSample(n))
        //
        // Substituting and rearranging:
        //   1.    deploymentTimestamp + (n - 1) * accrualAdjustmentPeriodSeconds - averageStartTime
        //       < targetAverageAgeSeconds
        //      <= deploymentTimestamp + n * accrualAdjustmentPeriodSeconds - averageStartTime
        //
        //   2.    (n - 1) * accrualAdjustmentPeriodSeconds
        //       < averageStartTime + targetAverageAgeSeconds - deploymentTimestamp
        //      <= n * accrualAdjustmentPeriodSeconds
        //
        //   3. n - 1 < (averageStartTime + targetAverageAgeSeconds - deploymentTimestamp) / accrualAdjustmentPeriodSeconds <= n
        //
        // Using equivalence `n = ceil(x) <=> n - 1 < x <= n` we arrive at:
        //   n = ceil((averageStartTime + targetAverageAgeSeconds - deploymentTimestamp) / accrualAdjustmentPeriodSeconds)
        //
        // We can calculate `ceil(a / b)` using `Math.ceilDiv(a, b)`.
        uint256 adjustmentPeriodCountWhenTargetIsExceeded = Math.ceilDiv(
            averageStartTime + targetAverageAgeSeconds - deploymentTimestamp,
            accrualAdjustmentPeriodSeconds
        );

        if (updatedAccrualAdjustmentPeriodCount < adjustmentPeriodCountWhenTargetIsExceeded) {
            // No adjustment needed; target average age hasn't been exceeded yet
            return (_storedAccrualParameter, updatedAccrualAdjustmentPeriodCount);
        }

        uint256 numberOfAdjustments = updatedAccrualAdjustmentPeriodCount - Math.max(
            _storedAccrualAdjustmentCount,
            adjustmentPeriodCountWhenTargetIsExceeded - 1
        );

        updatedAccrualParameter = Math.max(
            _storedAccrualParameter * decPow(accrualAdjustmentMultiplier, numberOfAdjustments) / 1e18,
            minimumAccrualParameter
        );
    }

    function _updateAccrualParameter() internal returns (uint256) {
        uint256 storedAccrualParameter = accrualParameter;
        uint256 storedAccrualAdjustmentPeriodCount = accrualAdjustmentPeriodCount;

        (uint256 updatedAccrualParameter, uint256 updatedAccrualAdjustmentPeriodCount) =
            _calcUpdatedAccrualParameter(storedAccrualParameter, storedAccrualAdjustmentPeriodCount);

        if (updatedAccrualAdjustmentPeriodCount != storedAccrualAdjustmentPeriodCount) {
            accrualAdjustmentPeriodCount = updatedAccrualAdjustmentPeriodCount;

            if (updatedAccrualParameter != storedAccrualParameter) {
                accrualParameter = updatedAccrualParameter;
            }
        }

        return updatedAccrualParameter;
    }

    function getBondData(uint256 _bondID) external view returns (uint256, uint256) {
        return (idToBondData[_bondID].lusdAmount, idToBondData[_bondID].startTime);
    }

    /* Placeholder function that returns a simple total acquired LUSD metric equal to the sum of:
    *
    * Yearn LUSD vault balance
    * plus
    * the LUSD cash-in value of the Curve LP shares in the Yearn Curve vault
    * minus
    * the total pending LUSD.
    *
    *
    * In practice, the total acquired LUSD calculation will depend on the specifics of how Yearn vaults calculate
    their balances and incorporate the yield, and whether we implement a toll on chicken-ins (and therefore divert some permanent DEX liquidity) */
    function _getTotalAcquiredLUSD(uint256 _lusdInYearn) public view returns (uint256) {
        return  _getAcquiredLUSDInYearn(_lusdInYearn) + getAcquiredLUSDInCurve();
    }

    function _getAcquiredLUSDInYearn(uint256 _lusdInYearn) public view returns (uint256) {
        /* In principle, the acquired LUSD is always the delta between the LUSD deposited to Yearn and the total pending LUSD.
        * When sLUSD supply == 0 (i.e. before the "first" chicken-in), this delta should be 0. However in practice, due to rounding
        * error in Yearn's share calculation the delta can be negative. We assume that a negative delta always corresponds to 0 acquired LUSD.
        *
        * TODO: Determine if this is the only situation whereby the delta can be negative. Potentially enforce some minimum
        * chicken-in value so that acquired LUSD always more than covers any rounding error in the share value.
        */
        uint256 acquiredLUSDInYearn = _lusdInYearn - totalPendingLUSD;

        uint256 permanentLUSDInYearn = getPermanentLUSDInYearn();
        if (acquiredLUSDInYearn > permanentLUSDInYearn) {
            acquiredLUSDInYearn -= permanentLUSDInYearn;
        } else {
            return 0; // TODO: is this possible?
        }

        return acquiredLUSDInYearn;
    }

    function getTotalLPAndLUSDInCurve() public view returns (uint256, uint256) {
        uint256 lusd3CRVInYearn = calcTotalYearnCurveVaultShareValue();
        uint256 totalLUSDInCurve;
        if (lusd3CRVInYearn > 0) {
            totalLUSDInCurve = curvePool.calc_withdraw_one_coin(lusd3CRVInYearn, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL);
        }

        return (lusd3CRVInYearn, totalLUSDInCurve);
    }

    function getAcquiredLUSDInCurve() public view returns (uint256) {
        (, uint256 totalLUSDInCurve) = getTotalLPAndLUSDInCurve();
        return totalLUSDInCurve > permanentLUSD ? totalLUSDInCurve - permanentLUSD : 0;
    }

    function getPermanentLUSDInYearn() public view returns (uint256) {
        (, uint256 totalLUSDInCurve) = getTotalLPAndLUSDInCurve();
        return permanentLUSD > totalLUSDInCurve ? permanentLUSD - totalLUSDInCurve : 0;
    }

    function getPermanentLUSDInCurve() public view returns (uint256) {
        (, uint256 totalLUSDInCurve) = getTotalLPAndLUSDInCurve();
        return Math.min(totalLUSDInCurve, permanentLUSD);
    }

    // Calculates the LUSD value of this contract's Yearn LUSD Vault yTokens held by the ChickenBondManager
    function calcTotalYearnLUSDVaultShareValue() public view returns (uint256) {
        uint256 totalYTokensHeldByCBM = yearnLUSDVault.balanceOf(address(this));
        return totalYTokensHeldByCBM * yearnLUSDVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD3CRV value of LUSD Curve Vault yTokens held by the ChickenBondManager
    function calcTotalYearnCurveVaultShareValue() public view returns (uint256) {
        uint256 totalYTokensHeldByCBM = yearnCurveVault.balanceOf(address(this));
        return totalYTokensHeldByCBM * yearnCurveVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD value of this contract, including Yearn LUSD Vault and Curve Vault
    function calcTotalLUSDValue() external view returns (uint256) {
        (, uint256 totalLUSDInCurve) = getTotalLPAndLUSDInCurve();
        return calcTotalYearnLUSDVaultShareValue() + totalLUSDInCurve;
    }

    // Returns the yTokens needed to make a partial withdrawal of the CBM's total vault deposit
    function calcCorrespondingYTokens(IYearnVault _yearnVault, uint256 _wantedTokenAmount, uint256 _CBMTotalVaultDeposit) internal view returns (uint256) {
        uint256 yTokensHeldByCBM = _yearnVault.balanceOf(address(this));
        uint256 yTokensToBurn = yTokensHeldByCBM * _wantedTokenAmount / _CBMTotalVaultDeposit;
        return yTokensToBurn;
    }

    function _calcSystemBackingRatio(uint256 _lusdInYearn) public view returns (uint256) {
        uint256 totalSLUSDSupply = sLUSDToken.totalSupply();
        uint256 totalAcquiredLUSD = _getTotalAcquiredLUSD(_lusdInYearn);

        /* TODO: Determine how to define the backing ratio when there is 0 sLUSD and 0 totalAcquiredLUSD,
        * i.e. before the first chickenIn. For now, return a backing ratio of 1. Note: Both quantities would be 0
        * also when the sLUSD supply is fully redeemed.
        */
        //if (totalSLUSDSupply == 0  && totalAcquiredLUSD == 0) {return 1e18;}
        //if (totalSLUSDSupply == 0) {return MAX_UINT256;}
        if (totalSLUSDSupply == 0) {return 1e18;}

        return  totalAcquiredLUSD * 1e18 / totalSLUSDSupply;
    }

    // Internal getter for calculating the bond sLUSD cap based on bonded amount and backing ratio
    function _calcBondSLUSDCap(uint256 _bondedAmount, uint256 _backingRatio) internal pure returns (uint256) {
        // TODO: potentially refactor this -  i.e. have a (1 / backingRatio) function for more precision
        return _bondedAmount * 1e18 / _backingRatio;
    }

    // --- 'require' functions

    function _requireCallerOwnsBond(uint256 _bondID) internal view {
        require(msg.sender == bondNFT.ownerOf(_bondID), "CBM: Caller must own the bond");
    }

    function _requireNonZeroAmount(uint256 _amount) internal pure {
        require(_amount > 0, "CBM: Amount must be > 0");
    }

    // --- External getter convenience functions ---

    function calcAccruedSLUSD(uint256 _bondID) external view returns (uint256) {
        BondData memory bond = idToBondData[_bondID];
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return _calcAccruedSLUSD(bond.startTime, _getTaxedBondAmount(bond.lusdAmount), calcSystemBackingRatio(), updatedAccrualParameter);
    }

    function calcBondSLUSDCap(uint256 _bondID) external view returns (uint256) {
        uint256 backingRatio = calcSystemBackingRatio();

        BondData memory bond = idToBondData[_bondID];

        return _calcBondSLUSDCap(_getTaxedBondAmount(bond.lusdAmount), backingRatio);
    }

    function getTotalAcquiredLUSD() external view returns (uint256) {
        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        return _getTotalAcquiredLUSD(lusdInYearn);
    }

    function getAcquiredLUSDInYearn() public view returns (uint256) {
        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        return _getAcquiredLUSDInYearn(lusdInYearn);
    }

    function getOwnedLUSDInSP() external view returns (uint256) {
        return getAcquiredLUSDInYearn() + getPermanentLUSDInYearn();
    }

    function getOwnedLUSDInCurve() external view returns (uint256) {
        return getAcquiredLUSDInCurve() + getPermanentLUSDInCurve();
    }

    function calcSystemBackingRatio() public view returns (uint256) {
        uint256 lusdInYearn = calcTotalYearnLUSDVaultShareValue();
        return _calcSystemBackingRatio(lusdInYearn);
    }

    function calcUpdatedAccrualParameter() external view returns (uint256) {
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return updatedAccrualParameter;
    }
}
