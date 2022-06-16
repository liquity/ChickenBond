// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./utils/ChickenMath.sol";

import "./Interfaces/jar.sol";
import "./Interfaces/IBancorNetwork.sol";
import "./Interfaces/IBancorNetworkInfo.sol";
import "./Interfaces/ICurveLiquidityGaugeV4.sol";

import "./Interfaces/IBondNFT.sol";
import "./Interfaces/IBLQTYToken.sol";
import "./Interfaces/ILQTYChickenBondManager.sol";

//import "forge-std/console.sol";


contract LQTYChickenBondManager is ChickenMath, ILQTYChickenBondManager {
    // ChickenBonds contracts and addresses
    IBondNFT immutable public bondNFT;

    IERC20 immutable public lqtyToken;
    IBLQTYToken immutable public bLQTYToken;

    // External contracts and addresses
    IJar immutable public pickleJar;
    IBancorNetwork immutable public bancorNetwork;
    IBancorNetworkInfo immutable public bancorNetworkInfo;
    IERC20 immutable public bntLQTYToken;                         // Bancor LQTY pool taken
    ICurveLiquidityGaugeV4 immutable public curveLiquidityGauge;  // For bLQTY/LQTY AMM rewards

    // --- Data structures ---

    struct ExternalAdresses {
        address bondNFTAddress;
        address lqtyTokenAddress;
        address bLQTYTokenAddress;
        address pickleJarAddress;
        address bancorNetworkInfoAddress;
        address curveLiquidityGaugeAddress;
    }

    struct BondData {
        uint256 lqtyAmount;
        uint256 startTime;
    }

    uint256 private pendingLQTY;
    uint256 private permanentLQTY;

    uint256 public lastRedemptionTime; // The timestamp of the latest redemption
    uint256 public baseRedemptionRate; // The latest base redemption rate
    mapping (uint256 => BondData) private idToBondData;

    // --- Constants ---

    uint256 immutable public CHICKEN_IN_AMM_FEE;

    uint256 constant MAX_UINT256 = type(uint256).max;

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

    uint256 public totalWeightedStartTimes; // Sum of `lqtyAmount * startTime` for all outstanding bonds (used to tell weighted average bond age)

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
        uint256 _CHICKEN_IN_AMM_FEE
    )
    {
        bondNFT = IBondNFT(_externalContractAddresses.bondNFTAddress);
        lqtyToken = IERC20(_externalContractAddresses.lqtyTokenAddress);
        bLQTYToken = IBLQTYToken(_externalContractAddresses.bLQTYTokenAddress);

        deploymentTimestamp = block.timestamp;
        targetAverageAgeSeconds = _targetAverageAgeSeconds;
        accrualParameter = _initialAccrualParameter;
        minimumAccrualParameter = _minimumAccrualParameter;
        accrualAdjustmentMultiplier = 1e18 - _accrualAdjustmentRate;
        accrualAdjustmentPeriodSeconds = _accrualAdjustmentPeriodSeconds;

        pickleJar = IJar(_externalContractAddresses.pickleJarAddress);
        bancorNetworkInfo = IBancorNetworkInfo(_externalContractAddresses.bancorNetworkInfoAddress);
        bancorNetwork = IBancorNetwork(bancorNetworkInfo.network());
        bntLQTYToken = IERC20(bancorNetworkInfo.poolToken(_externalContractAddresses.lqtyTokenAddress));
        curveLiquidityGauge = ICurveLiquidityGaugeV4(_externalContractAddresses.curveLiquidityGaugeAddress);
        CHICKEN_IN_AMM_FEE = _CHICKEN_IN_AMM_FEE;

        // TODO: Decide between one-time infinite LQTY approval (lower gas cost per user tx, less secure
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lqtyToken.approve(_externalContractAddresses.pickleJarAddress, MAX_UINT256);
        lqtyToken.approve(address(bancorNetwork), MAX_UINT256);
        lqtyToken.approve(_externalContractAddresses.curveLiquidityGaugeAddress, MAX_UINT256);
    }

    // --- User-facing functions ---

    function createBond(uint256 _lqtyAmount) external returns (uint256) {
        _requireNonZeroAmount(_lqtyAmount);

        _updateAccrualParameter();

        // Mint the bond NFT to the caller and get the bond ID
        uint256 bondID = bondNFT.mint(msg.sender);

        //Record the user’s bond data: bond_amount and start_time
        BondData memory bondData;
        bondData.lqtyAmount = _lqtyAmount;
        bondData.startTime = block.timestamp;
        idToBondData[bondID] = bondData;

        // Funds from outstanding bonds belong to Pending bucket until they are chickened in or out
        pendingLQTY += _lqtyAmount;

        // We need to keep track of weighted bond ages to update the accrual parameter
        totalWeightedStartTimes += _lqtyAmount * block.timestamp;

        // Pull LQTY from user
        lqtyToken.transferFrom(msg.sender, address(this), _lqtyAmount);

        // Deposit the LQTY to Pickle Jar
        pickleJar.deposit(_lqtyAmount);

        return bondID;
    }

    function chickenOut(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];

        delete idToBondData[_bondID];
        pendingLQTY -= bond.lqtyAmount;
        totalWeightedStartTimes -= bond.lqtyAmount * bond.startTime;

        uint256 previousLQTYBalance = lqtyToken.balanceOf(address(this));

        /* In practice, there could be edge cases where the pendingLQTY is not fully backed:
        * - Pickle Jar hack that drains LQTY
        * - ...? (TODO)
        *
        * TODO: decide how to handle chickenOuts if/when the recorded pendingLQTY is not fully backed by actual
        * LQTY in the Pickle Jar. */

        uint256 pTokensInPickleJar = pickleJar.balanceOf(address(this));
        uint256 pTokensForBond = bond.lqtyAmount * 1e18 / pickleJar.getRatio();
        uint256 pTokensToWithdraw = Math.min(pTokensForBond, pTokensInPickleJar);  // avoids revert due to rounding error if system contains only 1 bonder
        pickleJar.withdraw(pTokensToWithdraw);

        uint256 lqtyToWithdraw = lqtyToken.balanceOf(address(this)) - previousLQTYBalance;

        lqtyToken.transfer(msg.sender, lqtyToWithdraw);

        bondNFT.burn(_bondID);
    }

    function _withdrawFromPickleJar(uint256 _lqtyAmount, uint256 _lqtyInPickleJar) internal returns (uint256) {
        uint256 lqtyBalanceDelta;

        uint256 pTokensFromPickleJar = _calcCorrespondingPTokens(_lqtyAmount, _lqtyInPickleJar);

        if (pTokensFromPickleJar > 0) {
            uint256 lqtyBalanceBefore = lqtyToken.balanceOf(address(this));
            pickleJar.withdraw(pTokensFromPickleJar);
            lqtyBalanceDelta = lqtyToken.balanceOf(address(this)) - lqtyBalanceBefore;
        }

        return lqtyBalanceDelta;
    }

    // Divert acquired yield to LQTY/bLQTY AMM LP rewards staking contract
    // It happens on the very first chicken in event of the system, or any time that redemptions deplete bLQTY total supply to zero
    function _firstChickenIn() internal {
        // Assumption: When there have been no chicken ins since the bLQTY supply was set to 0 (either due to system deployment, or full bLQTY redemption),
        // all acquired LQTY must necessarily be pure yield.

        uint256 lqtyInPickleJar = calcTotalPickleJarShareValue();
        uint256 lqtyFromInitialYieldInPickleJar = _getAcquiredLQTYInPickleJar(lqtyInPickleJar);
        uint256 lqtyWithdrawnFromPickleJar;
        if (lqtyFromInitialYieldInPickleJar > 0) {
            lqtyWithdrawnFromPickleJar = _withdrawFromPickleJar(lqtyFromInitialYieldInPickleJar, lqtyInPickleJar);
            if (lqtyWithdrawnFromPickleJar > 0) {
                curveLiquidityGauge.deposit_reward_token(address(lqtyToken), lqtyWithdrawnFromPickleJar);
            }
        }

        // Revenue generated in bancor, only possible if it’s a “second first chicken-in”, i.e,
        // if acquired was depleted through redemptions, but permanent kept generating yield.
        // Bancor has a cooldown period of 7 days for withdrawals, so it would be quite complex to manage this asynchronously.
        // Instead we just make it all permanent.
        // TODO: Can it be >?
        assert(permanentLQTY <= calcTotalBancorPoolShareValue());
        permanentLQTY = calcTotalBancorPoolShareValue();
    }

    function chickenIn(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        /* Upon the first chicken-in after a) system deployment or b) redemption of the full bLQTY supply, divert
         * any earned yield to the bLQTY-LQTY AMM for fairness.
         */
        if (bLQTYToken.totalSupply() == 0) {
            _firstChickenIn();
        }

        uint256 updatedAccrualParameter = _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];
        (uint256 chickenInFeeAmount, uint256 bondAmountMinusChickenInFee) = _getBondWithChickenInFeeApplied(bond.lqtyAmount);

        uint256 lqtyInPickleJar = calcTotalPickleJarShareValue();
        uint256 lqtyAcquiredInPickleJar = _getAcquiredLQTYInPickleJar(lqtyInPickleJar);
        uint256 lqtyAcquiredInBancorPool = getAcquiredLQTYInBancorPool();
        uint256 accruedLQTY = _calcAccruedAmount(bond.startTime, bondAmountMinusChickenInFee, updatedAccrualParameter);
        uint256 backingRatio = _calcSystemBackingRatio(lqtyAcquiredInPickleJar + lqtyAcquiredInBancorPool);
        uint256 accruedBLQTY = accruedLQTY * 1e18 / backingRatio;

        delete idToBondData[_bondID];

        // Subtract the bonded amount from the total pending LQTY (and implicitly increase the total acquired LQTY)
        pendingLQTY -= bond.lqtyAmount;
        totalWeightedStartTimes -= bond.lqtyAmount * bond.startTime;

        // As Bancor autocompounds, and permanent revenue should go to acquired bucket,
        // we subtract the generated fees from the amount to deposit to Bancor
        // to avoid having to withdraw from Bancor as much as possible
        uint256 lqtySurplus = bondAmountMinusChickenInFee - accruedLQTY;
        uint256 lqtyToDepositToBancor = lqtySurplus > lqtyAcquiredInBancorPool ?
            lqtySurplus - lqtyAcquiredInBancorPool :
            lqtySurplus;

        // Add the surplus to the permanent bucket by depositing into Bancor
        permanentLQTY = permanentLQTY + lqtySurplus;

        // Due to rounding errors, obtained LQTY amount can differ from requested amount
        // We dump this error to Chicken in fee, and leave permament amount untouched
        // Theoretically it may happen that the rounding error was even bigger than the fee
        // (in that case we set the fee to zero)
        uint256 lqtyWithdrawn = _withdrawFromPickleJar(lqtyToDepositToBancor + chickenInFeeAmount, lqtyInPickleJar);
        chickenInFeeAmount = lqtyWithdrawn > lqtyToDepositToBancor ? lqtyWithdrawn - lqtyToDepositToBancor : 0;

        // Deposit to Bancor
        bancorNetwork.deposit(address(lqtyToken), lqtyToDepositToBancor);

        // Transfer the chicken in fee to the LQTY/bLQTY AMM LP Rewards staking contract during normal mode.
        if (chickenInFeeAmount > 0) {
            curveLiquidityGauge.deposit_reward_token(address(lqtyToken), chickenInFeeAmount);
        }

        bLQTYToken.mint(msg.sender, accruedBLQTY);
        bondNFT.burn(_bondID);

    }

    function redeem(uint256 _bLQTYToRedeem) external returns (uint256, uint256) {
        _requireNonZeroAmount(_bLQTYToRedeem);
        uint256 totalBLQTYSupply = bLQTYToken.totalSupply();
        require(_bLQTYToRedeem <= totalBLQTYSupply, "Amount to redeem bigger than total supply");

        uint256 fractionOfBLQTYToRedeem = _bLQTYToRedeem * 1e18 / totalBLQTYSupply;

        // Calculate redemption fraction to withdraw, given that we leave the fee inside the acquired bucket.
        uint256 redemptionFeePercentage = _updateRedemptionFeePercentage(fractionOfBLQTYToRedeem);
        uint256 fractionOfAcquiredLQTYToWithdraw = fractionOfBLQTYToRedeem * (1e18 - redemptionFeePercentage) / 1e18;

        // Calculate the LQTY to withdraw from Pickle, and send the corresponding pTokens to redeemer
        uint256 lqtyInPickleJar = calcTotalPickleJarShareValue();
        uint256 pTokensFromPickleJar;
        if (lqtyInPickleJar > 0) {
            uint256 lqtyToWithdrawFromPickleJar = _getAcquiredLQTY(lqtyInPickleJar) * fractionOfAcquiredLQTYToWithdraw / 1e18;
            pTokensFromPickleJar = _calcCorrespondingPTokens(lqtyToWithdrawFromPickleJar, lqtyInPickleJar);

            pickleJar.transfer(msg.sender, pTokensFromPickleJar);
        }

        // Redeem also from the Acquired bucket in Bancor generated through auto-compounded fees
        // Redemption fee will also stay in the acquired bucket, as we are not modifying `permanentLQTY`.
        uint256 lqtyToWithdrawFromBancorPool = getAcquiredLQTYInBancorPool() * fractionOfAcquiredLQTYToWithdraw / 1e18;
        // Calculate the pool tokens to withdraw from Bancor, and send them to redeemer
        uint256 bnTokensFromBancorPool;
        if (lqtyToWithdrawFromBancorPool > 0) {
            bnTokensFromBancorPool = bancorNetworkInfo.underlyingToPoolToken(address(lqtyToken), lqtyToWithdrawFromBancorPool);
            bntLQTYToken.transfer(msg.sender, bnTokensFromBancorPool);
        }

        _requireNonZeroAmount(pTokensFromPickleJar + bnTokensFromBancorPool);

        // Burn the redeemed bLQTY
        bLQTYToken.burn(msg.sender, _bLQTYToRedeem);

        return (pTokensFromPickleJar, bnTokensFromBancorPool);
    }

    // --- Helper functions ---

    // Calc decayed redemption rate
    function calcRedemptionFeePercentage(uint256 _fractionOfBLQTYToRedeem) public view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastRedemption();
        uint256 decayFactor = decPow(MINUTE_DECAY_FACTOR, minutesPassed);

        uint256 decayedBaseRedemptionRate = baseRedemptionRate * decayFactor / DECIMAL_PRECISION;

        // Increase redemption base rate with the new redeemed amount
        uint256 newBaseRedemptionRate = decayedBaseRedemptionRate + _fractionOfBLQTYToRedeem / BETA;
        newBaseRedemptionRate = Math.min(newBaseRedemptionRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%
        //assert(newBaseRedemptionRate <= DECIMAL_PRECISION); // This is already enforced in the line above

        return newBaseRedemptionRate;
    }

    // Update the base redemption rate and the last redemption time (only if time passed >= decay interval. This prevents base rate griefing)
    function _updateRedemptionFeePercentage(uint256 _fractionOfBLQTYToRedeem) internal returns (uint256) {
        uint256 newBaseRedemptionRate = calcRedemptionFeePercentage(_fractionOfBLQTYToRedeem);
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

    function _getBondWithChickenInFeeApplied(uint256 _bondLQTYAmount) internal view returns (uint256, uint256) {
        uint256 chickenInFeeAmount = _bondLQTYAmount * CHICKEN_IN_AMM_FEE / 1e18;
        uint256 bondAmountMinusChickenInFee = _bondLQTYAmount - chickenInFeeAmount;

        return (chickenInFeeAmount, bondAmountMinusChickenInFee);
    }

    function _getBondAmountMinusChickenInFee(uint256 _bondLQTYAmount) internal view returns (uint256) {
        (, uint256 bondAmountMinusChickenInFee) = _getBondWithChickenInFeeApplied(_bondLQTYAmount);
        return bondAmountMinusChickenInFee;
    }

    // Internal getter for calculating accrued LQTY/bLQTY based on BondData struct
    function _calcAccruedAmount(uint256 _startTime, uint256 _capAmount, uint256 _accrualParameter) internal view returns (uint256) {
        // All bonds have a non-zero creation timestamp, so return accrued sLQTY 0 if the startTime is 0
        if (_startTime == 0) {return 0;}

        // Scale `bondDuration` up to an 18 digit fixed-point number.
        // This lets us add it to `accrualParameter`, which is also an 18-digit FP.
        uint256 bondDuration = 1e18 * (block.timestamp - _startTime);

        uint256 accruedAmount = _capAmount * bondDuration / (bondDuration + _accrualParameter);
        assert(accruedAmount < _capAmount);

        return accruedAmount;
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
            pendingLQTY == 0
        ) {
            return (_storedAccrualParameter, updatedAccrualAdjustmentPeriodCount);
        }

        uint256 averageStartTime = totalWeightedStartTimes / pendingLQTY;

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

    function _calcSystemBackingRatio(uint256 _totalAcquiredLQTY) internal view returns (uint256) {
        uint256 totalBLQTYSupply = bLQTYToken.totalSupply();

        /* We define the backing ratio as 1 when there is 0 bLQTY and 0 totalAcquiredLQTY,
        * i.e. before the first chickenIn.
        * Note: Both quantities would be 0 also when the bLQTY supply is fully redeemed.
        */
        if (totalBLQTYSupply == 0) { return 1e18; }
        assert(_totalAcquiredLQTY > 0);

        return _totalAcquiredLQTY * 1e18 / totalBLQTYSupply;
    }

    // Internal getter for calculating the bond bLQTY cap based on bonded amount and backing ratio
    function _calcBondBLQTYCap(uint256 _bondedAmount, uint256 _backingRatio) internal pure returns (uint256) {
        // TODO: potentially refactor this -  i.e. have a (1 / backingRatio) function for more precision
        return _bondedAmount * 1e18 / _backingRatio;
    }

    // Internal getters for acquired bucket

    // Total Acquired bucket
    function _getAcquiredLQTY(uint256 _lqtyInPickleJar) internal view returns (uint256) {
        return _getAcquiredLQTYInPickleJar(_lqtyInPickleJar) + getAcquiredLQTYInBancorPool();
    }

    // Acquired bucket in Pickle
    function _getAcquiredLQTYInPickleJar(uint256 _lqty) internal view returns (uint256) {
        uint256 pendingLQTYCached = pendingLQTY;

        /* In principle, the acquired LQTY is always the delta between the LQTY deposited to Pickle and the total pending LQTY.
        * When bLQTY supply == 0 (i.e. before the "first" chicken-in), this delta should be 0.
        * TODO: However in practice, due to rounding error in Pickle's share calculation the delta can be negative.
        * We assume that a negative delta always corresponds to 0 acquired LQTY.
        *
        * TODO: Determine if this is the only situation whereby the delta can be negative. Potentially enforce some minimum
        * chicken-in value so that acquired LQTY always more than covers any rounding error in the share value.
        */
        if (_lqty <= pendingLQTYCached) { return 0; }

        // Acquired LQTY is what's left after subtracting pending portion
        return _lqty - pendingLQTYCached;
    }

    // Acquired bucket in Bancor (generated by auto-compounded revenue)
    function getAcquiredLQTYInBancorPool() public view returns (uint256) {
        // TODO: Can it be negative?
        //console.log(permanentLQTY, "permane");
        //console.log(calcTotalBancorPoolShareValue(), "calcTotalBancorPoolShareValue");

        return calcTotalBancorPoolShareValue() - permanentLQTY;
    }


    // Returns the pTokens needed to make a partial withdrawal of the CBM's total jar deposit
    function _calcCorrespondingPTokens(uint256 _wantedTokenAmount, uint256 _CBMTotalJarDeposit) internal view returns (uint256) {
        uint256 pTokensHeldByCBM = pickleJar.balanceOf(address(this));

        // Rounding can cause total jar deposit to be lower than wanted amount (and make withdrawal to revert when withdrawing all)
        if (_wantedTokenAmount > _CBMTotalJarDeposit) { return pTokensHeldByCBM; }

        uint256 pTokensToBurn = pTokensHeldByCBM * _wantedTokenAmount / _CBMTotalJarDeposit;
        return pTokensToBurn;
    }

    // --- 'require' functions

    function _requireCallerOwnsBond(uint256 _bondID) internal view {
        require(msg.sender == bondNFT.ownerOf(_bondID), "CBM: Caller must own the bond");
    }

    function _requireNonZeroAmount(uint256 _amount) internal pure {
        require(_amount > 0, "CBM: Amount must be > 0");
    }

    // --- Getter convenience functions ---

    // Bond getters

    function getBondData(uint256 _bondID) external view returns (uint256, uint256) {
        return (idToBondData[_bondID].lqtyAmount, idToBondData[_bondID].startTime);
    }

    function calcAccruedLQTY(uint256 _bondID) external view returns (uint256) {
        BondData memory bond = idToBondData[_bondID];

        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);

        return _calcAccruedAmount(bond.startTime, _getBondAmountMinusChickenInFee(bond.lqtyAmount), updatedAccrualParameter);
    }

    function calcAccruedBLQTY(uint256 _bondID) external view returns (uint256) {
        BondData memory bond = idToBondData[_bondID];

        uint256 bondBLQTYCap = _calcBondBLQTYCap(_getBondAmountMinusChickenInFee(bond.lqtyAmount), calcSystemBackingRatio());

        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);

        return _calcAccruedAmount(bond.startTime, bondBLQTYCap, updatedAccrualParameter);
    }

    function calcBondBLQTYCap(uint256 _bondID) external view returns (uint256) {
        uint256 backingRatio = calcSystemBackingRatio();

        BondData memory bond = idToBondData[_bondID];

        return _calcBondBLQTYCap(_getBondAmountMinusChickenInFee(bond.lqtyAmount), backingRatio);
    }

    // Native token value getters

    function calcTotalPickleJarShareValue() public view returns (uint256) {
        uint256 totalPTokensHeldByCBM = pickleJar.balanceOf(address(this));
        return totalPTokensHeldByCBM * pickleJar.getRatio() / 1e18;
    }

    function calcTotalBancorPoolShareValue() public view returns (uint256) {
        return bancorNetworkInfo.poolTokenToUnderlying(address(lqtyToken), bntLQTYToken.balanceOf(address(this)));
    }

    // Calculates the LQTY value of this contract, including Pickle LQTY Jar and Bancor pool
    function calcTotalLQTYValue() external view returns (uint256) {
        return calcTotalPickleJarShareValue() + calcTotalBancorPoolShareValue();
    }

    // Bucket getters

    function getPendingLQTY() external view returns (uint256) {
        return pendingLQTY;
    }

    function getAcquiredLQTY() public view returns (uint256) {
        uint256 lqty = calcTotalPickleJarShareValue();
        return _getAcquiredLQTY(lqty);
    }

    function getPermanentLQTY() external view returns (uint256) {
        return permanentLQTY;
    }

    function getOwnedLQTY() external view returns (uint256) {
        return getAcquiredLQTY() + permanentLQTY;
    }

    // Other getters

    function calcSystemBackingRatio() public view returns (uint256) {
        uint256 totalAcquiredLQTY = getAcquiredLQTY();
        return _calcSystemBackingRatio(totalAcquiredLQTY);
    }

    function calcUpdatedAccrualParameter() external view returns (uint256) {
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return updatedAccrualParameter;
    }
}
