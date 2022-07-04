// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./utils/ChickenMath.sol";

import "./Interfaces/IBondNFT.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/IBLUSDToken.sol";
import "./Interfaces/IBAMM.sol";
import "./Interfaces/IYearnVault.sol";
import "./Interfaces/ICurvePool.sol";
import "./Interfaces/IYearnRegistry.sol";
import "./Interfaces/IChickenBondManager.sol";
import "./Interfaces/ICurveLiquidityGaugeV4.sol";

//import "forge-std/console.sol";


contract ChickenBondManager is ChickenMath, IChickenBondManager {

    // ChickenBonds contracts and addresses
    IBondNFT immutable public bondNFT;

    IBLUSDToken immutable public bLUSDToken;
    ILUSDToken immutable public lusdToken;

    // External contracts and addresses
    ICurvePool immutable public curvePool; // LUSD meta-pool (i.e. coin 0 is LUSD, coin 1 is LP token from a base pool)
    ICurvePool immutable public curveBasePool; // base pool of curvePool
    IBAMM immutable public bammSPVault; // B.Protocol Stability Pool vault
    IYearnVault immutable public yearnCurveVault;
    IYearnRegistry immutable public yearnRegistry;
    ICurveLiquidityGaugeV4 immutable public curveLiquidityGauge;

    address immutable public yearnGovernanceAddress;

    uint256 immutable public CHICKEN_IN_AMM_FEE;

    uint256 private pendingLUSD;          // Total pending LUSD. It will always be in SP (B.Protocol)
    uint256 private permanentLUSDInSP;    // B.Protocol Liquity Stability Pool vault
    uint256 private permanentLUSDInCurve; // Yearn Curve LUSD-3CRV vault
    uint256 private bammLUSDDebt;         // Amount “owed” by B.Protocol to ChickenBonds, equals deposits - withdrawals + rewards

    // --- Data structures ---

    struct ExternalAdresses {
        address bondNFTAddress;
        address lusdTokenAddress;
        address curvePoolAddress;
        address curveBasePoolAddress;
        address bammSPVaultAddress;
        address yearnCurveVaultAddress;
        address yearnRegistryAddress;
        address yearnGovernanceAddress;
        address bLUSDTokenAddress;
        address curveLiquidityGaugeAddress;
    }

    struct BondData {
        uint256 lusdAmount;
        uint256 startTime;
    }

    uint256 public firstChickenInTime; // Timestamp of the first chicken in after bLUSD supply is zero
    uint256 public totalWeightedStartTimes; // Sum of `lusdAmount * startTime` for all outstanding bonds (used to tell weighted average bond age)
    uint256 public lastRedemptionTime; // The timestamp of the latest redemption
    uint256 public baseRedemptionRate; // The latest base redemption rate
    mapping (uint256 => BondData) public idToBondData;

    /* migration: flag which determines whether the system is in migration mode.

    When migration mode has been triggered:

    - No funds are held in the permanent bucket. Liquidity is either pending, or acquired
    - Bond creation and public shifter functions are disabled
    - Users with an existing bond may still chicken in or out
    - Chicken-ins will no longer send the LUSD surplus to the permanent bucket. Instead, they refund the surplus to the bonder
    - bLUSD holders may still redeem
    - Redemption fees are zero
    */
    bool public migration;

    // --- Constants ---

    uint256 constant MAX_UINT256 = type(uint256).max;
    int128 public constant INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = 0;
    int128 constant INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL = 1;

    uint256 constant public SECONDS_IN_ONE_MINUTE = 60;

    uint256 constant public BOOTSTRAP_PERIOD_CHICKEN_IN = 7 days; // Min duration of first chicken-in
    uint256 constant public BOOTSTRAP_PERIOD_REDEEM = 7 days; // Redemption lock period after first chicken in

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

    uint256 constant CURVE_FEE_DENOMINATOR = 1e10;

    // Thresholds of SP <=> Curve shifting
    uint256 public immutable curveDepositLUSD3CRVExchangeRateThreshold;
    uint256 public immutable curveWithdrawal3CRVLUSDExchangeRateThreshold;

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

    // --- Events ---

    event BaseRedemptionRateUpdated(uint256 _baseRedemptionRate);
    event LastRedemptionTimeUpdated(uint256 _lastRedemptionFeeOpTime);

    // --- Constructor ---

    constructor
    (
        ExternalAdresses memory _externalContractAddresses, // to avoid stack too deep issues
        uint256 _targetAverageAgeSeconds,
        uint256 _initialAccrualParameter,
        uint256 _minimumAccrualParameter,
        uint256 _accrualAdjustmentRate,
        uint256 _accrualAdjustmentPeriodSeconds,
        uint256 _CHICKEN_IN_AMM_FEE,
        uint256 _curveDepositDydxThreshold,
        uint256 _curveWithdrawalDxdyThreshold
    )
    {
        bondNFT = IBondNFT(_externalContractAddresses.bondNFTAddress);
        lusdToken = ILUSDToken(_externalContractAddresses.lusdTokenAddress);
        bLUSDToken = IBLUSDToken(_externalContractAddresses.bLUSDTokenAddress);
        curvePool = ICurvePool(_externalContractAddresses.curvePoolAddress);
        curveBasePool = ICurvePool(_externalContractAddresses.curveBasePoolAddress);
        bammSPVault = IBAMM(_externalContractAddresses.bammSPVaultAddress);
        yearnCurveVault = IYearnVault(_externalContractAddresses.yearnCurveVaultAddress);
        yearnRegistry = IYearnRegistry(_externalContractAddresses.yearnRegistryAddress);
        yearnGovernanceAddress = _externalContractAddresses.yearnGovernanceAddress;

        deploymentTimestamp = block.timestamp;
        targetAverageAgeSeconds = _targetAverageAgeSeconds;
        accrualParameter = _initialAccrualParameter;
        minimumAccrualParameter = _minimumAccrualParameter;
        accrualAdjustmentMultiplier = 1e18 - _accrualAdjustmentRate;
        accrualAdjustmentPeriodSeconds = _accrualAdjustmentPeriodSeconds;

        curveLiquidityGauge = ICurveLiquidityGaugeV4(_externalContractAddresses.curveLiquidityGaugeAddress);
        CHICKEN_IN_AMM_FEE = _CHICKEN_IN_AMM_FEE;

        uint256 fee = curvePool.fee(); // This is practically immutable (can only be set once, in `initialize()`)

        // By exchange rate, we mean the rate at which Curve exchanges LUSD <=> $ value of 3CRV (at the virtual price),
        // which is reduced by the fee.
        // For convenience, we want to parameterize our thresholds in terms of the spot prices -dy/dx & -dx/dy,
        // which are not exposed by Curve directly. Instead, we turn our thresholds into thresholds on the exchange rate
        // by taking into account the fee.
        curveDepositLUSD3CRVExchangeRateThreshold =
            _curveDepositDydxThreshold * (CURVE_FEE_DENOMINATOR - fee) / CURVE_FEE_DENOMINATOR;
        curveWithdrawal3CRVLUSDExchangeRateThreshold =
            _curveWithdrawalDxdyThreshold * (CURVE_FEE_DENOMINATOR - fee) / CURVE_FEE_DENOMINATOR;

        // TODO: Decide between one-time infinite LUSD approval to Yearn and Curve (lower gas cost per user tx, less secure
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lusdToken.approve(address(bammSPVault), MAX_UINT256);
        lusdToken.approve(address(curvePool), MAX_UINT256);
        curvePool.approve(address(yearnCurveVault), MAX_UINT256);
        lusdToken.approve(address(curveLiquidityGauge), MAX_UINT256);

        // Check that the system is hooked up to the correct latest Yearn vault
        assert(address(yearnCurveVault) == yearnRegistry.latestVault(address(curvePool)));
    }

    // --- User-facing functions ---

    function createBond(uint256 _lusdAmount) external returns (uint256) {
        _requireNonZeroAmount(_lusdAmount);
        _requireMigrationNotActive();

        _updateAccrualParameter();

        // Mint the bond NFT to the caller and get the bond ID
        uint256 bondID = bondNFT.mint(msg.sender);

        //Record the user’s bond data: bond_amount and start_time
        BondData memory bondData;
        bondData.lusdAmount = _lusdAmount;
        bondData.startTime = block.timestamp;
        idToBondData[bondID] = bondData;

        pendingLUSD += _lusdAmount;
        totalWeightedStartTimes += _lusdAmount * block.timestamp;

        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        // Deposit the LUSD to the B.Protocol LUSD vault
        _depositToBAMM(_lusdAmount);

        return bondID;
    }

    function chickenOut(uint256 _bondID, uint256 _minLUSD) external {
        _requireCallerOwnsBond(_bondID);

        _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];

        delete idToBondData[_bondID];
        pendingLUSD -= bond.lusdAmount;
        totalWeightedStartTimes -= bond.lusdAmount * bond.startTime;

        /* In practice, there could be edge cases where the pendingLUSD is not fully backed:
        * - Heavy liquidations, and before yield has been converted
        * - Heavy loss-making liquidations, i.e. at <100% CR
        * - SP or B.Protocol vault hack that drains LUSD
        *
        * The user can decide how to handle chickenOuts if/when the recorded pendingLUSD is not fully backed by actual
        * LUSD in B.Protocol / the SP, by adjusting _minLUSD */
        uint256 lusdToWithdraw = _requireEnoughLUSDInBAMM(bond.lusdAmount, _minLUSD);

        // Withdraw from B.Protocol LUSD vault
        _withdrawFromBAMM(lusdToWithdraw, msg.sender);

        bondNFT.burn(_bondID);
    }

    // transfer _lusdToTransfer to the LUSD/bLUSD AMM LP Rewards staking contract
    function _transferToRewardsStakingContract(uint256 _lusdToTransfer) internal {
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        curveLiquidityGauge.deposit_reward_token(address(lusdToken), _lusdToTransfer);

        assert(lusdBalanceBefore - lusdToken.balanceOf(address(this)) == _lusdToTransfer);
    }

    function _withdrawFromSPVaultAndTransferToRewardsStakingContract(uint256 _lusdAmount) internal {
        // Pull the LUSD amount from B.Protocol LUSD vault
        _withdrawFromBAMM(_lusdAmount, address(this));

        // Deposit in rewards contract
        _transferToRewardsStakingContract(_lusdAmount);
    }

    function _withdrawFromCurveVaultAndTransferToRewardsStakingContract(uint256 _yTokensToSwap) internal {
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));
        yearnCurveVault.withdraw(_yTokensToSwap);
        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // obtain LUSD from Curve
        if (LUSD3CRVBalanceDelta > 0) {
            uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
            curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);

            uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
            _transferToRewardsStakingContract(lusdBalanceDelta);
        }
    }

    /* Divert acquired yield to LUSD/bLUSD AMM LP rewards staking contract
     * It happens on the very first chicken in event of the system, or any time that redemptions deplete bLUSD total supply to zero
     * Assumption: When there have been no chicken ins since the bLUSD supply was set to 0 (either due to system deployment, or full bLUSD redemption),
     * all acquired LUSD must necessarily be pure yield.
     */
    function _firstChickenIn(uint256 _bondStartTime, uint256 _bammLUSDValue, uint256 _lusdInBAMMSPVault) internal returns (uint256) {
        assert(!migration);

        require(block.timestamp >= _bondStartTime + BOOTSTRAP_PERIOD_CHICKEN_IN, "CBM: First chicken in must wait until bootstrap period is over");
        firstChickenInTime = block.timestamp;

        uint256 acquiredLUSDInSP = _getAcquiredLUSDInSPFromBAMMValue(_bammLUSDValue);

        // Make sure that LUSD available in B.Protocol is at least as much as acquired
        // If first chicken in happens after an scenario of heavy liquidations and before ETH has been sold by B.Protocol
        // so that there’s not enough LUSD available in B.Protocol to transfer all the acquired bucket to the staking contract,
        // the system would start with a backing ratio greater than 1
        require(_lusdInBAMMSPVault >= acquiredLUSDInSP, "CBM: Not enough LUSD available in B.Protocol");

        // From SP Vault
        if (acquiredLUSDInSP > 0) {
            _withdrawFromSPVaultAndTransferToRewardsStakingContract(acquiredLUSDInSP);
        }

        // From Curve Vault
        uint256 lusdFromInitialYieldInCurve = getAcquiredLUSDInCurve();
        uint256 yTokensFromCurveVault = _calcCorrespondingYTokensInCurveVault(lusdFromInitialYieldInCurve);

        // withdraw LUSD3CRV from Curve Vault
        if (yTokensFromCurveVault > 0) {
            _withdrawFromCurveVaultAndTransferToRewardsStakingContract(yTokensFromCurveVault);
        }

        return _lusdInBAMMSPVault - acquiredLUSDInSP;
    }

    function chickenIn(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        uint256 updatedAccrualParameter = _updateAccrualParameter();
        (uint256 bammLUSDValue, uint256 lusdInBAMMSPVault) = _updateBAMMDebt();

        BondData memory bond = idToBondData[_bondID];
        (uint256 chickenInFeeAmount, uint256 bondAmountMinusChickenInFee) = _getBondWithChickenInFeeApplied(bond.lusdAmount);

        /* Upon the first chicken-in after a) system deployment or b) redemption of the full bLUSD supply, divert
        * any earned yield to the bLUSD-LUSD AMM for fairness.
        *
        * This is not done in migration mode since there is no need to send rewards to the staking contract.
        */
        if (bLUSDToken.totalSupply() == 0 && !migration) {
            lusdInBAMMSPVault = _firstChickenIn(bond.startTime, bammLUSDValue, lusdInBAMMSPVault);
        }

        uint256 backingRatio = _calcSystemBackingRatioFromBAMMValue(bammLUSDValue);
        uint256 accruedBLUSD = _calcAccruedBLUSD(bond.startTime, bondAmountMinusChickenInFee, backingRatio, updatedAccrualParameter);

        delete idToBondData[_bondID];

        // Subtract the bonded amount from the total pending LUSD (and implicitly increase the total acquired LUSD)
        pendingLUSD -= bond.lusdAmount;
        totalWeightedStartTimes -= bond.lusdAmount * bond.startTime;

        /* Get the LUSD amount to acquire from the bond, and the remaining surplus.
        *  Acquire LUSD in proportion to the system's current backing ratio, in order to maintain said ratio.
        */
        uint256 lusdToAcquire = accruedBLUSD * backingRatio / 1e18;
        uint256 lusdSurplus = bondAmountMinusChickenInFee - lusdToAcquire;

        // Handle the surplus LUSD from the chicken-in:
        if (!migration) { // In normal mode, add the surplus to the permanent bucket by increasing the permament tracker. This implicitly decreases the acquired LUSD.
            permanentLUSDInSP += lusdSurplus;
        } else { // In migration mode, withdraw surplus from B.Protocol and refund to bonder
            // TODO: should we allow to pass in a minimum value here too?
            (,lusdInBAMMSPVault,) = bammSPVault.getLUSDValue();
            uint256 lusdToRefund = Math.min(lusdSurplus, lusdInBAMMSPVault);
            if (lusdToRefund > 0) { _withdrawFromBAMM(lusdToRefund, msg.sender); }
        }

        bLUSDToken.mint(msg.sender, accruedBLUSD);
        bondNFT.burn(_bondID);

        // Transfer the chicken in fee to the LUSD/bLUSD AMM LP Rewards staking contract during normal mode.
        if (!migration && lusdInBAMMSPVault >= chickenInFeeAmount) {
            _withdrawFromSPVaultAndTransferToRewardsStakingContract(chickenInFeeAmount);
        }
    }

    function redeem(uint256 _bLUSDToRedeem, uint256 _minLUSDFromBAMMSPVault) external returns (uint256, uint256) {
        _requireNonZeroAmount(_bLUSDToRedeem);

        require(block.timestamp >= firstChickenInTime + BOOTSTRAP_PERIOD_REDEEM, "CBM: Redemption after first chicken in must wait until bootstrap period is over");

        (uint256 bammLUSDValue,) = _updateBAMMDebt();

        // Leaves redemption fees in the acquired bucket. */
        uint256 fractionOfBLUSDToRedeem = _bLUSDToRedeem * 1e18 / bLUSDToken.totalSupply();
        /* Calculate redemption fraction to withdraw, given that we leave the fee inside the acquired bucket.
        * No fee in migration mode. */
        uint256 redemptionFeePercentage = migration ? 0 : _updateRedemptionFeePercentage(fractionOfBLUSDToRedeem);
        uint256 fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18;

        // TODO: Both _requireEnoughLUSDInBAMM and _udateBAMMDebt call B.Protocol getLUSDValue, so it may be optmized
        // Calculate the LUSD to withdraw from LUSD vault, withdraw and send to redeemer
        uint256 lusdToWithdrawFromSP = _requireEnoughLUSDInBAMM(
            _getAcquiredLUSDInSPFromBAMMValue(bammLUSDValue) * fractionOfAcquiredLUSDToWithdraw / 1e18,
            _minLUSDFromBAMMSPVault
        );
        if (lusdToWithdrawFromSP > 0) { _withdrawFromBAMM(lusdToWithdrawFromSP, msg.sender); }

        // Calculate the LUSD to withdraw from Curve, and send the corresponding yTokens to redeemer
        uint256 lusdToWithdrawFromCurve = getAcquiredLUSDInCurve() * fractionOfAcquiredLUSDToWithdraw / 1e18;
        uint256 yTokensFromCurveVault = _calcCorrespondingYTokensInCurveVault(lusdToWithdrawFromCurve);
        if (yTokensFromCurveVault > 0) { yearnCurveVault.transfer(msg.sender, yTokensFromCurveVault); }

        _requireNonZeroAmount(lusdToWithdrawFromSP + yTokensFromCurveVault);

        // Burn the redeemed bLUSD
        bLUSDToken.burn(msg.sender, _bLUSDToRedeem);

        return (lusdToWithdrawFromSP, yTokensFromCurveVault);
    }

    function shiftLUSDFromSPToCurve(uint256 _maxLUSDToShift) external {
        _requireMigrationNotActive();

        (uint256 bammLUSDValue, uint256 lusdInBAMMSPVault) = _updateBAMMDebt();
        uint256 lusdOwnedInBAMMSPVault = bammLUSDValue - pendingLUSD;

        // Make sure pending bucket is not moved to Curve, so it can be withdrawn on chicken out
        uint256 clampedLUSDToShift = Math.min(_maxLUSDToShift, lusdOwnedInBAMMSPVault);

        // Make sure there’s enough LUSD available in B.Protocol
        clampedLUSDToShift = Math.min(clampedLUSDToShift, lusdInBAMMSPVault);

        _requireNonZeroAmount(clampedLUSDToShift);

        // Get the 3CRV virtual price only once, and use it for both initial and final check.
        // Adding LUSD liquidity to the meta-pool does not change 3CRV virtual price.
        uint256 _3crvVirtualPrice = curveBasePool.get_virtual_price();
        uint256 initialExchangeRate = _getLUSD3CRVExchangeRate(_3crvVirtualPrice);

        require(
            initialExchangeRate > curveDepositLUSD3CRVExchangeRateThreshold,
            "CBM: LUSD:3CRV exchange rate must be over the deposit threshold before SP->Curve shift"
        );

        /* Calculate and record the portion of LUSD withdrawn from the permanent B.Protocol LUSD bucket,
        assuming that withdrawing decreases both the permanent and acquired B.Protocol LUSD buckets by the same factor. */
        uint256 ratioPermanentToOwned = permanentLUSDInSP * 1e18 / lusdOwnedInBAMMSPVault;

        uint256 permanentLUSDShifted = clampedLUSDToShift * ratioPermanentToOwned / 1e18;
        permanentLUSDInSP -= permanentLUSDShifted;

        // Withdram LUSD from B.Protocol
        _withdrawFromBAMM(clampedLUSDToShift, address(this));

        // Deposit the received LUSD to Curve in return for LUSD3CRV-f tokens
        uint256 lusd3CRVBalanceBefore = curvePool.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LP tokens to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.add_liquidity([clampedLUSDToShift, 0], 0);
        uint256 lusd3CRVBalanceDelta = curvePool.balanceOf(address(this)) - lusd3CRVBalanceBefore;

        uint256 lusdInCurveBefore = getTotalLUSDInCurve();
        // Deposit the received LUSD3CRV-f to Yearn Curve vault
        yearnCurveVault.deposit(lusd3CRVBalanceDelta);

        /* Record the portion of LUSD added to the the permanent Yearn Curve bucket,
        assuming that receipt of yTokens increases both the permanent and acquired Yearn Curve buckets by the same factor as in B.Protocol. */
        uint256 lusdInCurve = getTotalLUSDInCurve();
        uint256 permanentLUSDCurveIncrease = (lusdInCurve - lusdInCurveBefore) * ratioPermanentToOwned / 1e18;

        permanentLUSDInCurve += permanentLUSDCurveIncrease;

        // Do price check: ensure the SP->Curve shift has decreased the LUSD:3CRV exchange rate, but not into unprofitable territory
        uint256 finalExchangeRate = _getLUSD3CRVExchangeRate(_3crvVirtualPrice);

        require(
            finalExchangeRate < initialExchangeRate &&
            finalExchangeRate >= curveDepositLUSD3CRVExchangeRateThreshold,
            "CBM: SP->Curve shift must decrease LUSD:3CRV exchange rate to a value above the deposit threshold"
        );
    }

    function shiftLUSDFromCurveToSP(uint256 _maxLUSDToShift) external {
        _requireMigrationNotActive();

        // We can’t shift more than what’s in Curve
        uint256 clampedLUSDToShift = Math.min(_maxLUSDToShift, getTotalLUSDInCurve());
        _requireNonZeroAmount(clampedLUSDToShift);

        // Get the 3CRV virtual price only once, and use it for both initial and final check.
        // Removing LUSD liquidity from the meta-pool does not change 3CRV virtual price.
        uint256 _3crvVirtualPrice = curveBasePool.get_virtual_price();
        uint256 initialExchangeRate = _get3CRVLUSDExchangeRate(_3crvVirtualPrice);

        // Here we're using the 3CRV:LUSD exchange rate (with 3CRV being valued at its virtual price),
        // which increases as LUSD price decreases, hence the direction of the inequality.
        require(
            initialExchangeRate > curveWithdrawal3CRVLUSDExchangeRateThreshold,
            "CBM: 3CRV:LUSD exchange rate must be above the withdrawal threshold before Curve->SP shift"
        );

        uint256 lusdInCurve = getTotalLUSDInCurve();

        // Convert yTokens to LUSD3CRV-f
        uint256 lusd3CRVBalanceBefore = curvePool.balanceOf(address(this));

        uint256 yTokensToBurnFromCurveVault = _calcCorrespondingYTokensInCurveVault(clampedLUSDToShift);
        yearnCurveVault.withdraw(yTokensToBurnFromCurveVault);
        uint256 lusd3CRVBalanceDelta = curvePool.balanceOf(address(this)) - lusd3CRVBalanceBefore;

        // Withdraw LUSD from Curve
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LUSD to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.remove_liquidity_one_coin(lusd3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        /* Calculate and record the portion of LUSD withdrawn from the permanent Yearn Curve bucket,
           assuming that burning yTokens decreases both the permanent and acquired Yearn Curve buckets by the same factor. */
        uint256 ratioPermanentToOwned = permanentLUSDInCurve * 1e18 / lusdInCurve;  // All funds in Curve are owned
        uint256 permanentLUSDWithdrawn = lusdBalanceDelta * ratioPermanentToOwned / 1e18;
        permanentLUSDInCurve -= permanentLUSDWithdrawn;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == _lusdToShift);

        // Deposit the received LUSD to B.Protocol LUSD vault
        _depositToBAMM(lusdBalanceDelta);

        /* Calculate and record the portion of LUSD added to the the permanent B.Protocol bucket,
        assuming that depositing increases both the permanent and acquired B.Protocol buckets by the same factor as in Curve. */
        uint256 permanentLUSDIncrease = lusdBalanceDelta * ratioPermanentToOwned / 1e18;
        permanentLUSDInSP += permanentLUSDIncrease;

        // Ensure the Curve->SP shift has decreased the 3CRV:LUSD exchange rate, but not into unprofitable territory
        uint256 finalExchangeRate = _get3CRVLUSDExchangeRate(_3crvVirtualPrice);

        require(
            finalExchangeRate < initialExchangeRate &&
            finalExchangeRate >= curveWithdrawal3CRVLUSDExchangeRateThreshold,
            "CBM: Curve->SP shift must increase 3CRV:LUSD exchange rate to a value above the withdrawal threshold"
        );
    }

    // --- B.Protocol debt functions ---

    // If the actual balance of B.Protocol is higher than our internal accounting,
    // it means that B.Protocol has had gains (through sell of ETH or LQTY).
    // We account for those gains
    // If the balance was lower (which would mean losses), we expect them to be eventually recovered
    function _getInternalBAMMLUSDValue() internal view returns (uint256) {
        (, uint256 lusdInBAMMSPVault,) = bammSPVault.getLUSDValue();

        return Math.max(bammLUSDDebt, lusdInBAMMSPVault);
    }

    // TODO: Should we make this one publicly callable, so that external getters can be up to date (by previously calling this)?
    // Returns the value updated
    function _updateBAMMDebt() internal returns (uint256, uint256) {
        (, uint256 lusdInBAMMSPVault,) = bammSPVault.getLUSDValue();
        uint256 bammLUSDDebtCached = bammLUSDDebt;

        // If the actual balance of B.Protocol is higher than our internal accounting,
        // it means that B.Protocol has had gains (through sell of ETH or LQTY).
        // We account for those gains
        // If the balance was lower (which would mean losses), we expect them to be eventually recovered
        if (lusdInBAMMSPVault > bammLUSDDebtCached) {
            bammLUSDDebt = lusdInBAMMSPVault;
            return (lusdInBAMMSPVault, lusdInBAMMSPVault);
        }

        return (bammLUSDDebtCached, lusdInBAMMSPVault);
    }

    function _depositToBAMM(uint256 _lusdAmount) internal {
        bammSPVault.deposit(_lusdAmount);
        bammLUSDDebt += _lusdAmount;
    }

    function _withdrawFromBAMM(uint256 _lusdAmount, address _to) internal {
        bammSPVault.withdraw(_lusdAmount, _to);
        bammLUSDDebt -= _lusdAmount;
    }

    // --- Migration functionality ---

    /* Migration function callable one-time and only by Yearn governance.
    * Moves all permanent LUSD in Curve to the Curve acquired bucket.
    */
    function activateMigration() external {
        _requireCallerIsYearnGovernance();
        _requireMigrationNotActive();

        migration = true;

        // Zero the permament LUSD trackers. This implicitly makes all permament liquidity acquired (and redeemable)
        permanentLUSDInSP = 0;
        permanentLUSDInCurve = 0;
    }

    // --- Fee share ---

    function sendFeeShare(uint256 _lusdAmount) external {
        _requireCallerIsYearnGovernance();
        require(!migration, "CBM: Receive fee share only in normal mode");

        // Move LUSD from caller to CBM and deposit to B.Protocol LUSD Vault
        lusdToken.transferFrom(yearnGovernanceAddress, address(this), _lusdAmount);
        _depositToBAMM(_lusdAmount);
    }

    // --- Helper functions ---

    function _getLUSD3CRVExchangeRate(uint256 _3crvVirtualPrice) internal view returns (uint256) {
        // Get the amount of 3CRV that would be received by swapping 1 LUSD (after deduction of fees)
        // If p_{LUSD:3CRV} is the price of LUSD quoted in 3CRV, then this returns p_{LUSD:3CRV} * (1 - fee)
        // as long as the pool is large enough so that 1 LUSD doesn't introduce significant slippage.
        uint256 dy = curvePool.get_dy(INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL, 1e18);

        return dy * _3crvVirtualPrice / 1e18;
    }

    function _get3CRVLUSDExchangeRate(uint256 _3crvVirtualPrice) internal view returns (uint256) {
        // Get the amount of LUSD that would be received by swapping 1 3CRV (after deduction of fees)
        // If p_{3CRV:LUSD} is the price of 3CRV quoted in LUSD, then this returns p_{3CRV:LUSD} * (1 - fee)
        // as long as the pool is large enough so that 1 3CRV doesn't introduce significant slippage.
        uint256 dy = curvePool.get_dy(INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 1e18);

        return dy * 1e18 / _3crvVirtualPrice;
    }

    // Calc decayed redemption rate
    function calcRedemptionFeePercentage(uint256 _fractionOfBLUSDToRedeem) public view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastRedemption();
        uint256 decayFactor = decPow(MINUTE_DECAY_FACTOR, minutesPassed);

        uint256 decayedBaseRedemptionRate = baseRedemptionRate * decayFactor / DECIMAL_PRECISION;

        // Increase redemption base rate with the new redeemed amount
        uint256 newBaseRedemptionRate = decayedBaseRedemptionRate + _fractionOfBLUSDToRedeem / BETA;
        newBaseRedemptionRate = Math.min(newBaseRedemptionRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%
        //assert(newBaseRedemptionRate <= DECIMAL_PRECISION); // This is already enforced in the line above

        return newBaseRedemptionRate;
    }

    // Update the base redemption rate and the last redemption time (only if time passed >= decay interval. This prevents base rate griefing)
    function _updateRedemptionFeePercentage(uint256 _fractionOfBLUSDToRedeem) internal returns (uint256) {
        uint256 newBaseRedemptionRate = calcRedemptionFeePercentage(_fractionOfBLUSDToRedeem);
        baseRedemptionRate = newBaseRedemptionRate;
        emit BaseRedemptionRateUpdated(newBaseRedemptionRate);

        uint256 timePassed = block.timestamp - lastRedemptionTime;

        if (timePassed >= SECONDS_IN_ONE_MINUTE) {
            lastRedemptionTime = block.timestamp;
            emit LastRedemptionTimeUpdated(block.timestamp);
        }

        return newBaseRedemptionRate;
    }

    function _minutesPassedSinceLastRedemption() internal view returns (uint256) {
        return (block.timestamp - lastRedemptionTime) / SECONDS_IN_ONE_MINUTE;
    }

    function _getBondWithChickenInFeeApplied(uint256 _bondLUSDAmount) internal view returns (uint256, uint256) {
        // Apply zero fee in migration mode
        if (migration) {return (0, _bondLUSDAmount);}

        // Otherwise, apply the constant fee rate
        uint256 chickenInFeeAmount = _bondLUSDAmount * CHICKEN_IN_AMM_FEE / 1e18;
        uint256 bondAmountMinusChickenInFee = _bondLUSDAmount - chickenInFeeAmount;

        return (chickenInFeeAmount, bondAmountMinusChickenInFee);
    }

    function _getBondAmountMinusChickenInFee(uint256 _bondLUSDAmount) internal view returns (uint256) {
        (, uint256 bondAmountMinusChickenInFee) = _getBondWithChickenInFeeApplied(_bondLUSDAmount);
        return bondAmountMinusChickenInFee;
    }

    // Internal getter for calculating accrued LUSD based on BondData struct
    function _calcAccruedBLUSD(uint256 _startTime, uint256 _lusdAmount, uint256 _backingRatio, uint256 _accrualParameter) internal view returns (uint256) {
        // All bonds have a non-zero creation timestamp, so return accrued sLQTY 0 if the startTime is 0
        if (_startTime == 0) {return 0;}
        uint256 bondBLUSDCap = _calcBondBLUSDCap(_lusdAmount, _backingRatio);

        // Scale `bondDuration` up to an 18 digit fixed-point number.
        // This lets us add it to `accrualParameter`, which is also an 18-digit FP.
        uint256 bondDuration = 1e18 * (block.timestamp - _startTime);

        uint256 accruedBLUSD = bondBLUSDCap * bondDuration / (bondDuration + _accrualParameter);
        assert(accruedBLUSD < bondBLUSDCap);

        return accruedBLUSD;
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
            pendingLUSD == 0
        ) {
            return (_storedAccrualParameter, updatedAccrualAdjustmentPeriodCount);
        }

        uint256 averageStartTime = totalWeightedStartTimes / pendingLUSD;

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

    // Returns the yTokens needed to make a partial withdrawal of the CBM's total vault deposit
    function _calcCorrespondingYTokensInCurveVault(uint256 _lusdAmount) internal view returns (uint256) {
        uint256 LUSD3CRVInCurve = calcTotalYearnCurveVaultShareValue();

        uint256 yTokensAmount;
        if (LUSD3CRVInCurve > 0) {
            uint256 LUSD3CRVfAmount = curvePool.calc_token_amount([_lusdAmount, 0], false);
            uint256 yTokensHeldByCBM = yearnCurveVault.balanceOf(address(this));
            yTokensAmount = yTokensHeldByCBM * LUSD3CRVfAmount / LUSD3CRVInCurve;
        }

        return yTokensAmount;
    }

    // Internal getter for calculating the bond bLUSD cap based on bonded amount and backing ratio
    function _calcBondBLUSDCap(uint256 _bondedAmount, uint256 _backingRatio) internal pure returns (uint256) {
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

    function _requireMigrationNotActive() internal view {
        require(!migration, "CBM: Migration must be not be active");
    }

    function _requireCallerIsYearnGovernance() internal view {
        require(msg.sender == yearnGovernanceAddress, "CBM: Only Yearn Governance can call");
    }

    function _requireEnoughLUSDInBAMM(uint256 _requestedLUSD, uint256 _minLUSD) internal view returns (uint256) {
        require(_requestedLUSD >= _minLUSD, "CBM: Min value cannot be greater than nominal amount");

        (, uint256 lusdInBAMMSPVault,) = bammSPVault.getLUSDValue();
        require(lusdInBAMMSPVault >= _minLUSD, "CBM: Not enough LUSD available in B.Protocol");

        uint256 lusdToWithdraw = Math.min(_requestedLUSD, lusdInBAMMSPVault);

        return lusdToWithdraw;
    }

    // --- Getter convenience functions ---

    // Bond getters

    function getBondData(uint256 _bondID) external view returns (uint256, uint256) {
        return (idToBondData[_bondID].lusdAmount, idToBondData[_bondID].startTime);
    }

    function getIdToBondData(uint256 _bondID) external view returns (uint256, uint256) {
        BondData memory bond = idToBondData[_bondID];
        return (bond.lusdAmount, bond.startTime);
    }

    function calcAccruedBLUSD(uint256 _bondID) external view returns (uint256) {
        BondData memory bond = idToBondData[_bondID];
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return _calcAccruedBLUSD(bond.startTime, _getBondAmountMinusChickenInFee(bond.lusdAmount), calcSystemBackingRatio(), updatedAccrualParameter);
    }

    function calcBondBLUSDCap(uint256 _bondID) external view returns (uint256) {
        uint256 backingRatio = calcSystemBackingRatio();

        BondData memory bond = idToBondData[_bondID];

        return _calcBondBLUSDCap(_getBondAmountMinusChickenInFee(bond.lusdAmount), backingRatio);
    }

    function getLUSDInBAMMSPVault() external view returns (uint256) {
        (, uint256 lusdInBAMMSPVault,) = bammSPVault.getLUSDValue();

        return lusdInBAMMSPVault;
    }

    // Native vault token value getters

    // Calculates the LUSD3CRV value of LUSD Curve Vault yTokens held by the ChickenBondManager
    function calcTotalYearnCurveVaultShareValue() public view returns (uint256) {
        uint256 totalYTokensHeldByCBM = yearnCurveVault.balanceOf(address(this));
        return totalYTokensHeldByCBM * yearnCurveVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD value of this contract, including B.Protocol LUSD Vault and Curve Vault
    function calcTotalLUSDValue() external view returns (uint256) {
        uint256 totalLUSDInCurve = getTotalLUSDInCurve();
        uint256 bammLUSDValue = _getInternalBAMMLUSDValue();

        return bammLUSDValue + totalLUSDInCurve;
    }

    function getTotalLUSDInCurve() public view returns (uint256) {
        uint256 LUSD3CRVInCurve = calcTotalYearnCurveVaultShareValue();
        uint256 totalLUSDInCurve;
        if (LUSD3CRVInCurve > 0) {
            totalLUSDInCurve = curvePool.calc_withdraw_one_coin(LUSD3CRVInCurve, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL);
        }

        return totalLUSDInCurve;
    }

    // Pending getter

    function getPendingLUSD() external view returns (uint256) {
        return pendingLUSD;
    }

    // Acquired getters

    // Acquired in B.Protocol + Acquired in Curve
    function getTotalAcquiredLUSD() external view returns (uint256) {
        return getAcquiredLUSDInSP() + getAcquiredLUSDInCurve();
    }

    function _getTotalAcquiredLUSDFromBAMMValue(uint256 _bammLUSDValue) internal view returns (uint256) {
        return _getAcquiredLUSDInSPFromBAMMValue(_bammLUSDValue) + getAcquiredLUSDInCurve();
    }

    function getAcquiredLUSDInSP() public view returns (uint256) {
        uint256 bammLUSDValue = _getInternalBAMMLUSDValue();
        return _getAcquiredLUSDInSPFromBAMMValue(bammLUSDValue);
    }

    function _getAcquiredLUSDInSPFromBAMMValue(uint256 _bammLUSDValue) public view returns (uint256) {
        uint256 pendingLUSDInSPVaultCached = pendingLUSD; // All pending LUSD is in B.Protocol vault.
        uint256 permanentLUSDInSPCached = permanentLUSDInSP;

        /* In principle, the acquired LUSD is always the delta between the LUSD deposited to B.Protocol and the total pending LUSD.
        * When bLUSD supply == 0 (i.e. before the "first" chicken-in), this delta should be 0.
        * However in practice, due to potential liquidation losses, the delta can be negative. We assume that a negative delta always corresponds to 0 acquired LUSD.
        *
        * TODO: Determine if this is the only situation whereby the delta can be negative. Potentially enforce some minimum
        * chicken-in value so that acquired LUSD always more than covers any rounding error in the share value.
        */
        uint256 acquiredLUSDInSP;

        // Acquired LUSD is what's left after subtracting pending and permament portions
        if (_bammLUSDValue > pendingLUSDInSPVaultCached + permanentLUSDInSPCached) {
            acquiredLUSDInSP = _bammLUSDValue - pendingLUSDInSPVaultCached - permanentLUSDInSPCached;
        }

        return acquiredLUSDInSP;
    }

    function getAcquiredLUSDInCurve() public view returns (uint256) {
        uint256 acquiredLUSDInCurve;

        // Get the LUSD value of the LUSD-3CRV tokens
        uint256 totalLUSDInCurve = getTotalLUSDInCurve();
        if (totalLUSDInCurve > permanentLUSDInCurve) {
            acquiredLUSDInCurve = totalLUSDInCurve - permanentLUSDInCurve;
        }

        return acquiredLUSDInCurve;
    }

    // Permanent getters

    function getPermanentLUSDInSP() external view returns (uint256) {
        return permanentLUSDInSP;
    }

    function getPermanentLUSDInCurve() external view returns (uint256) {
        return permanentLUSDInCurve;
    }

    // Owned getters

    function getOwnedLUSDInSP() external view returns (uint256) {
        return getAcquiredLUSDInSP() + permanentLUSDInSP;
    }

    function getOwnedLUSDInCurve() external view returns (uint256) {
        return getAcquiredLUSDInCurve() + permanentLUSDInCurve;
    }

    // Other getters

    function calcSystemBackingRatio() public view returns (uint256) {
        uint256 bammLUSDValue = _getInternalBAMMLUSDValue();
        return _calcSystemBackingRatioFromBAMMValue(bammLUSDValue);
    }

    function _calcSystemBackingRatioFromBAMMValue(uint256 _bammLUSDValue) public view returns (uint256) {
        uint256 totalBLUSDSupply = bLUSDToken.totalSupply();
        uint256 totalAcquiredLUSD = _getTotalAcquiredLUSDFromBAMMValue(_bammLUSDValue);

        /* TODO: Determine how to define the backing ratio when there is 0 bLUSD and 0 totalAcquiredLUSD,
         * i.e. before the first chickenIn. For now, return a backing ratio of 1. Note: Both quantities would be 0
         * also when the bLUSD supply is fully redeemed.
         */
        //if (totalBLUSDSupply == 0  && totalAcquiredLUSD == 0) {return 1e18;}
        //if (totalBLUSDSupply == 0) {return MAX_UINT256;}
        if (totalBLUSDSupply == 0) {return 1e18;}

        return  totalAcquiredLUSD * 1e18 / totalBLUSDSupply;
    }

    function calcUpdatedAccrualParameter() external view returns (uint256) {
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return updatedAccrualParameter;
    }

    function getBAMMLUSDDebt() external view returns (uint256) {
        return bammLUSDDebt;
    }
}
