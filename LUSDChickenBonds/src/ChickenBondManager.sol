// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./utils/ChickenMath.sol";

import "./Interfaces/IBondNFT.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/IBLUSDToken.sol";
import "./Interfaces/IYearnVault.sol";
import "./Interfaces/ICurvePool.sol";
import "./Interfaces/IYearnRegistry.sol";
import "./Interfaces/IChickenBondManager.sol";
import "./Interfaces/ICurveLiquidityGaugeV4.sol";

//import "forge-std/console.sol";


contract ChickenBondManager is Ownable, ChickenMath, IChickenBondManager {

    // ChickenBonds contracts and addresses
    IBondNFT immutable public bondNFT;

    IBLUSDToken immutable public bLUSDToken;
    ILUSDToken immutable public lusdToken;

    address immutable public lusdSiloAddress;

    // External contracts and addresses
    ICurvePool immutable public curvePool;
    IYearnVault immutable public yearnSPVault;
    IYearnVault immutable public yearnCurveVault;
    IYearnRegistry immutable public yearnRegistry;
    ICurveLiquidityGaugeV4 immutable public curveLiquidityGauge;

    address immutable public yearnGovernanceAddress;

    uint256 immutable public CHICKEN_IN_AMM_FEE;

    uint256 private permanentLUSDInSP;    // Yearn Liquity Stability Pool vault
    uint256 private permanentLUSDInCurve; // Yearn Curve LUSD-3CRV vault

    // --- Data structures ---

    struct ExternalAdresses {
        address bondNFTAddress;
        address lusdTokenAddress;
        address curvePoolAddress;
        address yearnSPVaultAddress;
        address yearnCurveVaultAddress;
        address yearnRegistryAddress;
        address yearnGovernanceAddress;
        address bLUSDTokenAddress;
        address curveLiquidityGaugeAddress;
        address lusdSiloAddress;
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

    /* migration: flag which determines whether the system is in migration mode.

    When migration mode has been triggered:

    - No funds are held in the Yearn LUSD vault. Liquidity is held in the Silo and Curve.
    - No funds are held in the permanent bucket. Liquidity is either pending, or acquired
    - All pending LUSD is held in the Silo
    - Bond creation and public shifter functions are disabled
    - Users with an existing bond may still chicken in or out
    - Chicken-ins will no longer send the LUSD surplus to the permanent bucket. Instead, they refund the surplus to the bonder
    - Chicken-outs pull the LUSD from the Silo's pending bucket
    - bLUSD holders may still redeem
    - Redemption fees are zero
    - Redemptions pull funds proportionally from the acquired buckets of the Silo and Curve.
    */
    bool public migration;

    // --- Constants ---

    uint256 constant MAX_UINT256 = type(uint256).max;
    int128 public constant INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = 0;
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
        lusdToken = ILUSDToken(_externalContractAddresses.lusdTokenAddress);
        bLUSDToken = IBLUSDToken(_externalContractAddresses.bLUSDTokenAddress);
        curvePool = ICurvePool(_externalContractAddresses.curvePoolAddress);
        yearnSPVault = IYearnVault(_externalContractAddresses.yearnSPVaultAddress);
        yearnCurveVault = IYearnVault(_externalContractAddresses.yearnCurveVaultAddress);
        yearnRegistry = IYearnRegistry(_externalContractAddresses.yearnRegistryAddress);
        yearnGovernanceAddress = _externalContractAddresses.yearnGovernanceAddress;
        lusdSiloAddress = _externalContractAddresses.lusdSiloAddress;

        deploymentTimestamp = block.timestamp;
        targetAverageAgeSeconds = _targetAverageAgeSeconds;
        accrualParameter = _initialAccrualParameter;
        minimumAccrualParameter = _minimumAccrualParameter;
        accrualAdjustmentMultiplier = 1e18 - _accrualAdjustmentRate;
        accrualAdjustmentPeriodSeconds = _accrualAdjustmentPeriodSeconds;

        curveLiquidityGauge = ICurveLiquidityGaugeV4(_externalContractAddresses.curveLiquidityGaugeAddress);
        CHICKEN_IN_AMM_FEE = _CHICKEN_IN_AMM_FEE;

        // TODO: Decide between one-time infinite LUSD approval to Yearn and Curve (lower gas cost per user tx, less secure
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lusdToken.approve(address(yearnSPVault), MAX_UINT256);
        lusdToken.approve(address(curvePool), MAX_UINT256);
        curvePool.approve(address(yearnCurveVault), MAX_UINT256);
        lusdToken.approve(address(curveLiquidityGauge), MAX_UINT256);

        // Check that the system is hooked up to the correct latest Yearn vaults
        assert(address(yearnSPVault) == yearnRegistry.latestVault(address(lusdToken)));
        // TODO: Check mainnet registry for the deployed Yearn Curve vault
        // assert(address(yearnCurveVault) == yearnRegistry.latestVault(address(curvePool)));

        renounceOwnership();
    }

    // --- User-facing functions ---

    function createBond(uint256 _lusdAmount) external {
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

        totalPendingLUSD += _lusdAmount;
        totalWeightedStartTimes += _lusdAmount * block.timestamp;

        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        // Deposit the LUSD to the Yearn LUSD vault
        yearnSPVault.deposit(_lusdAmount);
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

        uint256 lusdToWithdraw;

        if (!migration) { // In normal mode, withdraw from Yearn LUSD vault
            uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));

            uint256 lusdInLUSDVault = calcTotalYearnSPVaultShareValue();
            lusdToWithdraw = Math.min(bond.lusdAmount, lusdInLUSDVault);  // avoids revert due to rounding error if system contains only 1 bonder
            uint256 yTokensToSwapForLUSD = _calcCorrespondingYTokens(yearnSPVault, lusdToWithdraw, lusdInLUSDVault);
            yearnSPVault.withdraw(yTokensToSwapForLUSD);

            uint256 lusdBalanceAfter = lusdToken.balanceOf(address(this));
            uint256 lusdBalanceDelta = lusdBalanceAfter - lusdBalanceBefore;

            /* Transfer the LUSD balance delta resulting from the withdrawal, rather than the ideal bondedLUSD.
            * Reasoning: the LUSD balance delta can be slightly lower than the bondedLUSD due to floor division in the
            * yToken calculation prior to withdrawal. */
            lusdToken.transfer(msg.sender, lusdBalanceDelta);

        } else { // In migration mode, withdraw from the Silo
            lusdToWithdraw = Math.min(bond.lusdAmount, lusdToken.balanceOf(lusdSiloAddress));
            lusdToken.transferFrom(lusdSiloAddress, msg.sender, lusdToWithdraw);
        }

        bondNFT.burn(_bondID);
    }

    // transfer _yTokensToSwap to the LUSD/bLUSD AMM LP Rewards staking contract
    function _transferToRewardsStakingContract(uint256 _lusdToTransfer) internal {
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        curveLiquidityGauge.deposit_reward_token(address(lusdToken), _lusdToTransfer);

        assert(lusdBalanceBefore - lusdToken.balanceOf(address(this)) == _lusdToTransfer);
    }

    function _withdrawFromSPVaultAndTransferToRewardsStakingContract(uint256 _yTokensToSwap) internal {
        // Pull the LUSD amount from Yearn LUSD vault
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnSPVault.withdraw(_yTokensToSwap);

        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
        if (lusdBalanceDelta == 0) { return; }

        /* Transfer the LUSD balance delta resulting from the Yearn withdrawal, rather than the ideal lusdToRefund.
         * Reasoning: the LUSD balance delta can be slightly lower than the lusdToRefund due to floor division in the
         * yToken calculation prior to withdrawal. */
        _transferToRewardsStakingContract(lusdBalanceDelta);
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

    // Divert acquired yield to LUSD/bLUSD AMM LP rewards staking contract
    // It happens on the very first chicken in event of the system, or any time that redemptions deplete bLUSD total supply to zero
    function _firstChickenIn() internal {
        assert(!migration);

        /* Assumption: When there have been no chicken ins since the bLUSD supply was set to 0 (either due to system deployment, or full bLUSD redemption),
        /* all acquired LUSD must necessarily be pure yield.
        */
        // From SP Vault
        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        uint256 lusdFromInitialYieldInSP = _getAcquiredLUSDInSP(lusdInSP);
        if (lusdFromInitialYieldInSP > 0) {
            uint256 yTokensFromSPVault = _calcCorrespondingYTokens(yearnSPVault, lusdFromInitialYieldInSP, lusdInSP);
            if (yTokensFromSPVault > 0) {
                _withdrawFromSPVaultAndTransferToRewardsStakingContract(yTokensFromSPVault);
            }
        }

        // From Curve Vault
        uint256 LUSD3CRVInCurve = calcTotalYearnCurveVaultShareValue();
        if (LUSD3CRVInCurve > 0) {
            uint256 lusdFromInitialYieldInCurve = getAcquiredLUSDInCurve();
            uint256 LUSD3CRVfToBurn = curvePool.calc_token_amount([lusdFromInitialYieldInCurve, 0], false);
            uint256 yTokensFromCurveVault = _calcCorrespondingYTokens(yearnCurveVault, LUSD3CRVfToBurn, LUSD3CRVInCurve);

            // withdraw LUSD3CRV from Curve Vault
            if (yTokensFromCurveVault > 0) {
                _withdrawFromCurveVaultAndTransferToRewardsStakingContract(yTokensFromCurveVault);
            }
        }
    }

    function chickenIn(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        uint256 updatedAccrualParameter = _updateAccrualParameter();

        BondData memory bond = idToBondData[_bondID];
        (uint256 chickenInFeeAmount, uint256 bondAmountMinusChickenInFee) = _getBondWithChickenInFeeApplied(bond.lusdAmount);

        /* Upon the first chicken-in after a) system deployment or b) redemption of the full bLUSD supply, divert
        * any earned yield to the bLUSD-LUSD AMM for fairness.
        *
        * This is not done in migration mode since there is no need to send rewards to the staking contract.
        */
        if (bLUSDToken.totalSupply() == 0 && !migration) {
            _firstChickenIn();
        }

        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        uint256 backingRatio = _calcSystemBackingRatio(lusdInSP);
        uint256 accruedBLUSD = _calcAccruedBLUSD(bond.startTime, bondAmountMinusChickenInFee, backingRatio, updatedAccrualParameter);

        delete idToBondData[_bondID];

        // Subtract the bonded amount from the total pending LUSD (and implicitly increase the total acquired LUSD)
        totalPendingLUSD -= bond.lusdAmount;
        totalWeightedStartTimes -= bond.lusdAmount * bond.startTime;

        /* Get the LUSD amount to acquire from the bond, and the remaining surplus. Acquire LUSD in proportion to the system's
        current backing ratio,* in order to maintain said ratio. */
        uint256 lusdToAcquire = accruedBLUSD * backingRatio / 1e18;
        uint256 lusdSurplus = bondAmountMinusChickenInFee - lusdToAcquire;

        // Handle the surplus LUSD from the chicken-in:
        if (!migration) { // In normal mode, add the surplus to the permanent bucket by increasing the permament yToken tracker. This implicitly decreases the acquired LUSD.
            permanentLUSDInSP += lusdSurplus;
        } else { // In migration mode, withdraw surplus from LUSD silo and refund to bonder
            uint256 lusdToRefund = Math.min(lusdSurplus, lusdToken.balanceOf(lusdSiloAddress));
            lusdToken.transferFrom(lusdSiloAddress, msg.sender, lusdToRefund);
        }

        bLUSDToken.mint(msg.sender, accruedBLUSD);
        bondNFT.burn(_bondID);

        // Transfer the chicken in fee to the LUSD/bLUSD AMM LP Rewards staking contract during normal mode.
        if (!migration) {
            uint256 yTokensToSwapForChickenInFeeLUSD = _calcCorrespondingYTokens(yearnSPVault, chickenInFeeAmount, lusdInSP);
            _withdrawFromSPVaultAndTransferToRewardsStakingContract(yTokensToSwapForChickenInFeeLUSD);
        }
    }

    function redeem(uint256 _bLUSDToRedeem) external returns (uint256, uint256, uint256) {
        _requireNonZeroAmount(_bLUSDToRedeem);

        /* TODO: determine whether we should simply leave the fee in the acquired bucket, or add it to a permanent bucket.
        Current approach leaves redemption fees in the acquired bucket. */
        uint256 fractionOfBLUSDToRedeem = _bLUSDToRedeem * 1e18 / bLUSDToken.totalSupply();
        /* Calculate redemption fraction to withdraw, given that we leave the fee inside the acquired bucket.
        * No fee in migration mode. */
        uint256 redemptionFeePercentage = migration ? 0 : _updateRedemptionFeePercentage(fractionOfBLUSDToRedeem);
        uint256 fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18;

        // In normal mode, calculate the LUSD to withdraw from LUSD vault, and send the corresponding yTokens to redeemer
        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        uint256 yTokensFromSPVault;
        if (!migration && lusdInSP > 0) {
            uint256 lusdToWithdrawFromSP = _getAcquiredLUSDInSP(lusdInSP) * fractionOfAcquiredLUSDToWithdraw / 1e18;
            yTokensFromSPVault = _calcCorrespondingYTokens(yearnSPVault, lusdToWithdrawFromSP, lusdInSP);

            yearnSPVault.transfer(msg.sender, yTokensFromSPVault);
        }
        // Otherwise in migration mode, send LUSD from the Silo to the redeemer
        uint256 lusdFromSilo;
        if (migration) {
            lusdFromSilo = getAcquiredLUSDInSilo() * fractionOfAcquiredLUSDToWithdraw / 1e18;

            lusdToken.transferFrom(lusdSiloAddress, msg.sender, lusdFromSilo);
        }
        // In either mode, calculate the LUSD to withdraw from Curve, and send the corresponding yTokens to redeemer
        uint256 LUSD3CRVInCurve = calcTotalYearnCurveVaultShareValue();
        uint256 yTokensFromCurveVault;
        if (LUSD3CRVInCurve > 0) {
            uint256 lusdToWithdrawFromCurve = getAcquiredLUSDInCurve() * fractionOfAcquiredLUSDToWithdraw / 1e18;
            uint256 LUSD3CRVfToBurn = curvePool.calc_token_amount([lusdToWithdrawFromCurve, 0], false);
            yTokensFromCurveVault = _calcCorrespondingYTokens(yearnCurveVault, LUSD3CRVfToBurn, LUSD3CRVInCurve);

            yearnCurveVault.transfer(msg.sender, yTokensFromCurveVault);
        }

        _requireNonZeroAmount(yTokensFromSPVault + yTokensFromCurveVault + lusdFromSilo);

        // Burn the redeemed bLUSD
        bLUSDToken.burn(msg.sender, _bLUSDToRedeem);

        return (yTokensFromSPVault, yTokensFromCurveVault, lusdFromSilo);
    }

    function shiftLUSDFromSPToCurve(uint256 _lusdToShift) external {
        _requireNonZeroAmount(_lusdToShift);
        _requireMigrationNotActive();

        uint256 initialCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(initialCurveSpotPrice > 1e18, "CBM: Curve spot must be > 1.0 before SP->Curve shift");

        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();

        /* Calculate and record the portion of LUSD withdrawn from the permanent Yearn LUSD bucket,
        assuming that burning yTokens decreases both the permanent and acquired Yearn LUSD buckets by the same factor. */
        uint256 lusdOwnedLUSDVault = lusdInSP - totalPendingLUSD;
        uint256 ratioPermanentToOwned = permanentLUSDInSP * 1e18 / lusdOwnedLUSDVault;

        uint256 permanentLUSDShifted = _lusdToShift * ratioPermanentToOwned / 1e18;
        permanentLUSDInSP -= permanentLUSDShifted;

        // Convert yTokens to LUSD
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint256 yTokensToBurnFromLUSDVault = _calcCorrespondingYTokens(yearnSPVault, _lusdToShift, lusdInSP);
        yearnSPVault.withdraw(yTokensToBurnFromLUSDVault);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Curve in return for LUSD3CRV-f tokens
        uint256 lusd3CRVBalanceBefore = curvePool.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LP tokens to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.add_liquidity([lusdBalanceDelta, 0], 0);
        uint256 lusd3CRVBalanceDelta = curvePool.balanceOf(address(this)) - lusd3CRVBalanceBefore;

        uint256 lusdInCurveBefore = getTotalLUSDInCurve();
        // Deposit the received LUSD3CRV-f to Yearn Curve vault
        yearnCurveVault.deposit(lusd3CRVBalanceDelta);

        /* Record the portion of LUSD added to the the permanent Yearn Curve bucket,
        assuming that receipt of yTokens increases both the permanent and acquired Yearn Curve buckets by the same factor. */
        uint256 lusdInCurve = getTotalLUSDInCurve();
        uint256 permanentLUSDCurveIncrease = (lusdInCurve - lusdInCurveBefore) * ratioPermanentToOwned / 1e18;

        permanentLUSDInCurve += permanentLUSDCurveIncrease;

        // Do price check: ensure the SP->Curve shift has decreased the Curve spot price to not less than 1.0
        uint256 finalCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(finalCurveSpotPrice < initialCurveSpotPrice && finalCurveSpotPrice >=  1e18, "CBM: SP->Curve shift must decrease spot price to >= 1.0");
    }

    function shiftLUSDFromCurveToSP(uint256 _lusdToShift) external {
        _requireNonZeroAmount(_lusdToShift);
        _requireMigrationNotActive();

        uint256 initialCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(initialCurveSpotPrice < 1e18, "CBM: Curve spot must be < 1.0 before Curve->SP shift");

        //Calculate LUSD3CRV-f needed to withdraw LUSD from Curve
        uint256 lusd3CRVfToBurn = curvePool.calc_token_amount([_lusdToShift, 0], false);

        //Calculate yTokens to swap for LUSD3CRV-f
        (uint256 lusd3CRVInCurveVault, uint256 lusdInCurve) = getTotalLPAndLUSDInCurve();

        // Convert yTokens to LUSD3CRV-f
        uint256 lusd3CRVBalanceBefore = curvePool.balanceOf(address(this));

        uint256 yTokensToBurnFromCurveVault = _calcCorrespondingYTokens(yearnCurveVault, lusd3CRVfToBurn, lusd3CRVInCurveVault);
        yearnCurveVault.withdraw(yTokensToBurnFromCurveVault);
        uint256 lusd3CRVBalanceDelta = curvePool.balanceOf(address(this)) - lusd3CRVBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusd3CRVBalanceDelta == lusd3CRVfToBurn);

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
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Yearn LUSD vault
        yearnSPVault.deposit(lusdBalanceDelta);

        /* Calculate and record the portion of LUSD added to the the permanent Yearn Curve bucket,
        assuming that receipt of yTokens increases both the permanent and acquired Yearn Curve buckets by the same factor. */
        uint256 permanentLUSDIncrease = lusdBalanceDelta * ratioPermanentToOwned / 1e18;
        permanentLUSDInSP += permanentLUSDIncrease;

        // Ensure the Curve->SP shift has increased the Curve spot price to not more than 1.0
        uint256 finalCurveSpotPrice = _getCurveLUSDSpotPrice();
        require(finalCurveSpotPrice > initialCurveSpotPrice && finalCurveSpotPrice <=  1e18, "CBM: Curve->SP shift must increase spot price to <= 1.0");
    }

    // --- Migration functionality ---

    /* Migration function callable one-time and only by Yearn governance. Pulls all LUSD in the Yearn LUSD vault and dumps it into
    * a LUSDSilo contract, and moves all permanent LUSD in Curve to the Curve acquired bucket.
    */
    function activateMigration() external {
        _requireCallerIsYearnGovernance();
        _requireMigrationNotActive();

        migration = true;

        // Zero the permament yTokens trackers.  This implicitly makes all permament liquidity acquired (and redeemable)
        permanentLUSDInSP = 0;
        permanentLUSDInCurve = 0;

        _shiftAllLUSDInSPToSilo();
    }

    function _shiftAllLUSDInSPToSilo() internal {
        uint256 yTokensToBurnFromLUSDVault = yearnSPVault.balanceOf(address(this));

        // Convert all Yearn LUSD vault yTokens to LUSD
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnSPVault.withdraw(yTokensToBurnFromLUSDVault);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Transfer the received LUSD to the silo
        lusdToken.transfer(lusdSiloAddress, lusdBalanceDelta);
    }

    // --- Fee share ---

    function sendFeeShare(uint256 _lusdAmount) external {
        _requireCallerIsYearnGovernance();
        require(!migration, "CBM: Receive fee share only in normal mode");

        // Move LUSD from caller to CBM and deposit to Yearn LUSD Vault
        lusdToken.transferFrom(yearnGovernanceAddress, address(this), _lusdAmount);
        yearnSPVault.deposit(_lusdAmount);
    }

    // --- Helper functions ---

    function _getCurveLUSDSpotPrice() internal view returns (uint256) {
        // Get the Curve spot price of LUSD: the amount of 3CRV that would be received by swapping 1 LUSD
        return curvePool.get_dy_underlying(INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, INDEX_OF_3CRV_TOKEN_IN_CURVE_POOL, 1e18);
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
    function _getTotalAcquiredLUSD(uint256 _lusdInSP) internal view returns (uint256) {
        return  _getAcquiredLUSDInSP(_lusdInSP) + getAcquiredLUSDInCurve() + getAcquiredLUSDInSilo();
    }

    function _getAcquiredLUSDInSP(uint256 _lusdInSP) internal view returns (uint256) {
        // In normal mode, all pending LUSD is in Yearn SP vault. In migration mode, none is.
        uint256 pendingLUSDInSPVault = migration ? 0 : totalPendingLUSD;

        uint256 permanentLUSDInSPCached = permanentLUSDInSP;

        /* In principle, the acquired LUSD is always the delta between the LUSD deposited to Yearn and the total pending LUSD.
        * When bLUSD supply == 0 (i.e. before the "first" chicken-in), this delta should be 0. However in practice, due to rounding
        * error in Yearn's share calculation the delta can be negative. We assume that a negative delta always corresponds to 0 acquired LUSD.
        *
        * TODO: Determine if this is the only situation whereby the delta can be negative. Potentially enforce some minimum
        * chicken-in value so that acquired LUSD always more than covers any rounding error in the share value.
        */
        uint256 acquiredLUSDInSP;

        // Acquired LUSD is what's left after subtracting pending and permament portions
        if (_lusdInSP > pendingLUSDInSPVault + permanentLUSDInSPCached) {
            acquiredLUSDInSP = _lusdInSP - pendingLUSDInSPVault - permanentLUSDInSPCached;
        }

        return acquiredLUSDInSP;
    }

    // Returns the yTokens needed to make a partial withdrawal of the CBM's total vault deposit
    function _calcCorrespondingYTokens(IYearnVault _yearnVault, uint256 _wantedTokenAmount, uint256 _CBMTotalVaultDeposit) internal view returns (uint256) {
        uint256 yTokensHeldByCBM = _yearnVault.balanceOf(address(this));
        uint256 yTokensToBurn = yTokensHeldByCBM * _wantedTokenAmount / _CBMTotalVaultDeposit;
        return yTokensToBurn;
    }

    function _calcSystemBackingRatio(uint256 _lusdInSP) internal view returns (uint256) {
        uint256 totalBLUSDSupply = bLUSDToken.totalSupply();
        uint256 totalAcquiredLUSD = _getTotalAcquiredLUSD(_lusdInSP);

        /* TODO: Determine how to define the backing ratio when there is 0 bLUSD and 0 totalAcquiredLUSD,
        * i.e. before the first chickenIn. For now, return a backing ratio of 1. Note: Both quantities would be 0
        * also when the bLUSD supply is fully redeemed.
        */
        //if (totalBLUSDSupply == 0  && totalAcquiredLUSD == 0) {return 1e18;}
        //if (totalBLUSDSupply == 0) {return MAX_UINT256;}
        if (totalBLUSDSupply == 0) {return 1e18;}

        return  totalAcquiredLUSD * 1e18 / totalBLUSDSupply;
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

    // Native vault token value getters

    // Calculates the LUSD value of this contract's Yearn LUSD Vault yTokens held by the ChickenBondManager
    function calcTotalYearnSPVaultShareValue() public view returns (uint256) {
        uint256 totalYTokensHeldByCBM = yearnSPVault.balanceOf(address(this));
        return totalYTokensHeldByCBM * yearnSPVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD3CRV value of LUSD Curve Vault yTokens held by the ChickenBondManager
    function calcTotalYearnCurveVaultShareValue() public view returns (uint256) {
        uint256 totalYTokensHeldByCBM = yearnCurveVault.balanceOf(address(this));
        return totalYTokensHeldByCBM * yearnCurveVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD value of this contract, including Yearn LUSD Vault and Curve Vault
    function calcTotalLUSDValue() external view returns (uint256) {
        uint256 totalLUSDInCurve = getTotalLUSDInCurve();
        return calcTotalYearnSPVaultShareValue() + totalLUSDInCurve;
    }

    function getTotalLUSDInCurve() public view returns (uint256) {
        (, uint256 totalLUSDInCurve) = getTotalLPAndLUSDInCurve();

        return totalLUSDInCurve;
    }

    function getTotalLPAndLUSDInCurve() public view returns (uint256, uint256) {
        uint256 LUSD3CRVInCurve = calcTotalYearnCurveVaultShareValue();
        uint256 totalLUSDInCurve;
        if (LUSD3CRVInCurve > 0) {
            totalLUSDInCurve = curvePool.calc_withdraw_one_coin(LUSD3CRVInCurve, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL);
        }

        return (LUSD3CRVInCurve, totalLUSDInCurve);
    }

    // Acquired getters

    function getTotalAcquiredLUSD() external view returns (uint256) {
        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        return _getTotalAcquiredLUSD(lusdInSP);
    }

    function getAcquiredLUSDInSP() public view returns (uint256) {
        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        return _getAcquiredLUSDInSP(lusdInSP);
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

    function getAcquiredLUSDInSilo() public view returns (uint256) {
        if (!migration) { // In normal mode the silo doesn't contain any system funds
            return 0;
        } else { // In migration mode the silo contains some acquired LUSD, and all the pending LUSD
            return lusdToken.balanceOf(lusdSiloAddress) - totalPendingLUSD;
        }
    }

    // Permanent getters

    function getPermanentLUSDInSP() external view returns (uint256) {
        return permanentLUSDInSP;
    }

    function getPermanentLUSDInCurve() external view returns (uint256) {
        return permanentLUSDInCurve;
    }

    // Pending getter

    function getPendingLUSDInSilo() external view returns (uint256) {
        return migration ? totalPendingLUSD : 0;
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
        uint256 lusdInSP = calcTotalYearnSPVaultShareValue();
        return _calcSystemBackingRatio(lusdInSP);
    }

    function calcUpdatedAccrualParameter() external view returns (uint256) {
        (uint256 updatedAccrualParameter, ) = _calcUpdatedAccrualParameter(accrualParameter, accrualAdjustmentPeriodCount);
        return updatedAccrualParameter;
    }
}
