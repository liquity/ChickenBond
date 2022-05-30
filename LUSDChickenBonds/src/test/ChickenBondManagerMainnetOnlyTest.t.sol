pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";
import "../Interfaces/StrategyAPI.sol";


contract ChickenBondManagerMainnetOnlyTest is BaseTest, MainnetTestSetup {
    function _spHarvest() internal returns (uint256) {
        // get strategy
        address strategy = yearnSPVault.withdrawalQueue(0);
        // get keeper
        address keeper = StrategyAPI(strategy).keeper();

        // harvest
        uint256 prevValue = chickenBondManager.calcTotalYearnSPVaultShareValue();
        vm.startPrank(keeper);
        StrategyAPI(strategy).harvest();

        // some time passes to unlock profits
        vm.warp(block.timestamp + 600);
        vm.stopPrank();
        uint256 valueIncrease = chickenBondManager.calcTotalYearnSPVaultShareValue() - prevValue;
        return valueIncrease;
    }

    function _curveHarvest() internal returns (uint256) {
        // get strategy
        address strategy = yearnCurveVault.withdrawalQueue(0);
        // get keeper
        address keeper = StrategyAPI(strategy).keeper();

        // harvest
        uint256 prevValue = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        vm.startPrank(keeper);
        StrategyAPI(strategy).harvest();

        // some time passes to unlock profits
        vm.warp(block.timestamp + 30 days);
        vm.stopPrank();
        uint256 valueIncrease = chickenBondManager.calcTotalYearnCurveVaultShareValue() - prevValue;
        return valueIncrease;
    }

    // --- chickening in when sTOKEN supply is zero ---

    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = _spHarvest();

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), initialYield + chickenInFeeAmount, 7, "Balance of rewards contract doesn't match");

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), chickenInFeeAmount, 1, "Balance of rewards contract doesn't match");

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionAndSPHarvestTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = _spHarvest();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + chickenInFeeAmount,
            12,
            "Balance of rewards contract after A's chicken-in doesn't match"
        );

        vm.warp(block.timestamp + 600);

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A));
        vm.stopPrank();

        // Confirm total bLUSD supply is 0
        assertEq(bLUSDToken.totalSupply(), 0, "bLUSD supply not 0 after full redemption");

        // Yearn LUSD Vault gets some yield
        uint256 secondYield = _spHarvest();

        // B chickens in
        vm.startPrank(B);
        uint256 accruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        uint256 yieldFromFirstChickenInRedemptionFee = bLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + secondYield + 2 * chickenInFeeAmount + yieldFromFirstChickenInRedemptionFee,
            20,
            "Balance of rewards contract after B's chicken-in doesn't match"
        );

        // check CBM holds no LUSD
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0, "cbm holds non-zero lusd");

        // check bLUSD B balance
        assertEq(bLUSDToken.balanceOf(B), accruedBLUSD_B, "bLUSD balance of B doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionAndCurveHarvestTransfersToRewardsContract() external {
        uint256 bondAmount1 = 1000e18;
        uint256 bondAmount2 = 100e18;
        tip(address(lusdToken), A, bondAmount1 + bondAmount2);

        // create bond
        uint256 A_bondID = createBondForUser(A, bondAmount1);

        // wait 100 days
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // shift 50% to Curve
        shiftFractionFromSPToCurve(2);

        uint256 initialPermanentLUSDInSP = chickenBondManager.getPermanentLUSDInSP();
        uint256 initialPermanentLUSDInCurve = chickenBondManager.getPermanentLUSDInCurve();

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A));
        vm.stopPrank();

        // harvest curve
        uint256 curveYield = _curveHarvest();
        // TODO:
        //assertGt(curveYield, 0, "Yield generated in Curve vault should be greater than zero")

        // create bond
        A_bondID = createBondForUser(A, bondAmount2);

        // wait 100 days more
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        uint256 prevAcquiredLUSDInCurve = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 accruedBLUSD = chickenBondManager.calcAccruedBLUSD(A_bondID);

        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // checks
        // Acquired in SP vault
        assertApproximatelyEqual(
            chickenBondManager.getAcquiredLUSDInSP(),
            accruedBLUSD,
            1,
            "Acquired LUSD in SP mismatch"
        );
        // Permanent in SP vault
        assertApproximatelyEqual(
            chickenBondManager.getPermanentLUSDInSP(),
            initialPermanentLUSDInSP + _getAmountMinusChickenInFee(bondAmount2) - accruedBLUSD,
            1,
            "Permanent LUSD in SP mismatch"
        );

        // Acquired in Curve vault
        assertRelativeError(
            prevAcquiredLUSDInCurve,
            prevAcquiredLUSDInCurve + chickenBondManager.getAcquiredLUSDInCurve(),
            4e14, // 0.04%
            "Acquired LUSD in Curve mismatch"
        );
        // Permanent in Curve vault
        assertApproximatelyEqual(
            chickenBondManager.getPermanentLUSDInCurve(),
            initialPermanentLUSDInCurve,
            1,
            "Permanent LUSD in Curve mismatch"
        );

        // Balance in rewards contract
        // uint256 yieldFromFirstChickenInRedemptionFee = bLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertRelativeError(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            //curveYield + chickenInFeeAmount1 + chickenInFeeAmount2 + yieldFromFirstChickenInRedemptionFee,
            curveYield + _getChickenInFeeForAmount(bondAmount1) + _getChickenInFeeForAmount(bondAmount2) + bLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18,
            4e10, // 0.000004 %
            "Rewards contract balance mismatch"
        );
    }

    // --- redemption tests ---

    function testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction(uint256 redemptionFraction) public {
        // Fraction between 1 billion'th, and 100%.  If amount is too tiny, redemption can revert due to attempts to
        // withdraw 0 LUSDfrom Yearn (due to rounding in share calc).
        vm.assume(redemptionFraction <= 1e18 && redemptionFraction >= 1e9);

        // uint256 redemptionFraction = 1e9; // 50%
        uint256 percentageFee = chickenBondManager.calcRedemptionFeePercentage(redemptionFraction);
        // 1-r(1-f).  Fee is left inside system
        uint256 expectedFractionRemainingAfterRedemption = 1e18 - (redemptionFraction * (1e18 - percentageFee)) / 1e18;

        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);

        // time passes
        vm.warp(block.timestamp + 365 days);

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        vm.stopPrank();

        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        assertEq(bLUSDToken.totalSupply(), bLUSDToken.balanceOf(B));

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get acquired LUSD in Curve before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 permanentLUSDInCurveBefore = chickenBondManager.getPermanentLUSDInCurve();
        assertGt(acquiredLUSDInCurveBefore, 0, "Acquired in Curve should be greater than zero");
        assertGt(permanentLUSDInCurveBefore, 0, "Permanent in Curve should be greater than zero");

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(bLUSDToRedeem, bLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(bLUSDToRedeem);
        vm.stopPrank();

        // Check acquired LUSD in curve after has reduced by correct fraction
        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 expectedAcquiredLUSDInCurveAfter = acquiredLUSDInCurveBefore * expectedFractionRemainingAfterRedemption / 1e18;

        //console.log(acquiredLUSDInCurveBefore, "acquiredLUSDInCurveBefore");
        //console.log(acquiredLUSDInCurveAfter, "acquiredLUSDInCurveAfter");
        //console.log(expectedAcquiredLUSDInCurveAfter, "expectedAcquiredLUSDInCurveAfter");
        uint256 tolerance = acquiredLUSDInCurveBefore / 1000; // Assume 0.1% relative error tolerance
        assertApproximatelyEqual(acquiredLUSDInCurveAfter, expectedAcquiredLUSDInCurveAfter, tolerance, "Final acquired LUSD in Curve mismatch");
    }

    // --- shiftLUSDFromSPToCurve tests ---

    function testShiftLUSDFromSPToCurveRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        makeCurveSpotPriceAbove1(200_000_000e18);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Attempt to shift 0 LUSD
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.shiftLUSDFromSPToCurve(0);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenCurvePriceLessThan1() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        makeCurveSpotPriceBelow1(200_000_000e18);

        // Attempt to shift 10% of acquired LUSD in Yearn
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        // Try to shift the LUSD
        vm.expectRevert("CBM: Curve spot must be > 1.0 before SP->Curve shift");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenShiftWouldDropCurvePriceBelow1() public {
        // Artificially raise Yearn LUSD vault deposit limit to accommodate sufficient LUSD for the test
        vm.startPrank(yearnGovernanceAddress);
        yearnSPVault.setDepositLimit(1e27);
        vm.stopPrank();

        // A creates bond
        uint256 bondAmount = 500_000_000e18; // 500m

        tip(address(lusdToken), A, bondAmount);
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 1 year passes
        vm.warp(block.timestamp + 365 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // --- First check that the amount to shift *would* drop the curve price below 1.0, by having a whale
        // deposit it, checking Curve price, then withdrawing it again --- ///

        uint256 lusdAmount = 200_000_000e18;

        // Whale deposits to Curve pool and LUSD spot price drops < 1.0
        depositLUSDToCurveForUser(C, lusdAmount); // deposit 200m LUSD
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        //Whale withdraws their LUSD deposit, and LUSD spot price rises > 1.0 again
        vm.startPrank(C);
        uint256 whaleLPShares = curvePool.balanceOf(C);
        curvePool.remove_liquidity_one_coin(whaleLPShares, 0, 0);
        vm.stopPrank();
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // --- Now, attempt the shift that would drop the price below 1.0 ---
        vm.expectRevert("CBM: SP->Curve shift must decrease spot price to >= 1.0");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdAmount);
    }

    // CBM system trackers
    function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDBefore, 0);

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();

        // TODO: Why does the error margin need to be so large here when shifting from SP -> Curve?
        // It's bigger than a rounding error.
        // NOTE: Relative error seems fairly constant as bond size varies (~5th digit)
        // However, relative error increases/decreases as amount shifted increases/decreases
        // (4th digit when shifting all SP LUSD, 7th digit when shifting only 1% SP LUSD)
        assertRelativeError(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 1e14, "Acquired LUSD deviated too much after 1st shift");

        // Shift 10% of LUSD in SP (again, as this time Curve vault was not empty before, so it’s a better check for proportions)
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter2 = chickenBondManager.getTotalAcquiredLUSD();

        // TODO: Why does the error margin need to be so large here when shifting from SP -> Curve?
        // It's bigger than a rounding error.
        // NOTE: Relative error seems fairly constant as bond size varies (~5th digit)
        // However, relative error increases/decreases as amount shifted increases/decreases
        // (4th digit when shifting all SP LUSD, 7th digit when shifting only 1% SP LUSD)
        assertRelativeError(totalAcquiredLUSDAfter2, totalAcquiredLUSDAfter, 1e14, "Acquired LUSD deviated too much after 2nd shift");
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalPermanentLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // get CBM's recorded total permanent LUSD before
        uint256 totalPermanentLUSDBefore = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();
        assertGt(totalPermanentLUSDBefore, 0);

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total permanent LUSD hasn't changed
        uint256 totalPermanentLUSDAfter = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();

        // TODO: Why does the error margin need to be so large here when shifting from SP -> Curve?
        // It's bigger than a rounding error.
        // NOTE: Relative error seems fairly constant as bond size varies (~5th digit)
        // However, relative error increases/decreases as amount shifted increases/decreases
        // (4th digit when shifting all SP LUSD, 7th digit when shifting only 1% SP LUSD)
        assertRelativeError(totalPermanentLUSDAfter, totalPermanentLUSDBefore, 1e14, "Permanent LUSD deviated too much after 1st shift");


        // Shift 10% of LUSD in SP (again, as this time Curve vault was not empty before, so it’s a better check for proportions)
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total permanent LUSD hasn't changed
        uint256 totalPermanentLUSDAfter2 = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();

        // TODO: Why does the error margin need to be so large here when shifting from SP -> Curve?
        // It's bigger than a rounding error.
        // NOTE: Relative error seems fairly constant as bond size varies (~5th digit)
        // However, relative error increases/decreases as amount shifted increases/decreases
        // (4th digit when shifting all SP LUSD, 7th digit when shifting only 1% SP LUSD)
        assertRelativeError(totalPermanentLUSDAfter2, totalPermanentLUSDAfter, 1e14, "Permanent LUSD deviated too much after 2nd shift");
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMPendingLUSDTracker() public {
        uint256 bondAmount = 25e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);

       // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check pending LUSD After has not changed
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInSPTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check acquired LUSD in Yearn has decreased
        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();
        assertTrue(acquiredLUSDInSPAfter < acquiredLUSDInSPBefore);
    }

    function testShiftLUSDFromSPToCurveDecreasesCBMLUSDInSPTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get CBM's view of LUSD in Yearn
        uint256 lusdInSPBefore = chickenBondManager.calcTotalYearnSPVaultShareValue();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Yearn has decreased
        uint256 lusdInSPAfter = chickenBondManager.calcTotalYearnSPVaultShareValue();
        assertTrue(lusdInSPAfter < lusdInSPBefore);
    }

    function testShiftLUSDFromSPToCurveIncreasesCBMLUSDInCurveTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get CBM's view of LUSD in Curve before
        uint256 lusdInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Curve has inccreased
        uint256 lusdInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(lusdInCurveAfter > lusdInCurveBefore);
    }

    function testShiftLUSDFromSPToCurveLosesMinimalLUSD(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get the total LUSD in Yearn and Curve before
        uint256 cbmLUSDInSPBefore = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Get actual SP and Curve pool LUSD Balances before
        uint256 yearnSPVaultBalanceBefore =  lusdToken.balanceOf(address(yearnSPVault));
        uint256 CurveBalanceBefore = lusdToken.balanceOf(address(curvePool));

        // Shift to Curve
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10; // Shift 10% of total owned LUSD
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get the total LUSD in Yearn and Curve after
        uint256 cbmLUSDInSPAfter = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();

        // Get actual SP and Curve pool LUSD Balances after
        uint256 yearnSPVaultBalanceAfter = lusdToken.balanceOf(address(yearnSPVault));
        uint256 CurveBalanceAfter = lusdToken.balanceOf(address(curvePool));

        // Check Yearn LUSD vault decreases
        assertLt(cbmLUSDInSPAfter, cbmLUSDInSPBefore);
        assertLt(yearnSPVaultBalanceAfter, yearnSPVaultBalanceBefore);
        // Check Curve pool increases
        assertGt(cbmLUSDInCurveAfter, cbmLUSDInCurveBefore);
        assertGt(CurveBalanceAfter, CurveBalanceBefore);

        uint256 cbmyearnSPVaultDecrease = cbmLUSDInSPBefore - cbmLUSDInSPAfter; // Yearn LUSD vault decreases
        uint256 cbmCurveIncrease = cbmLUSDInCurveAfter - cbmLUSDInCurveBefore; // Curve increases

        uint256 yearnSPVaultBalanceDecrease = yearnSPVaultBalanceBefore - yearnSPVaultBalanceAfter;
        uint256 CurveBalanceIncrease = CurveBalanceAfter - CurveBalanceBefore;

        // Check that amount we can actually withdraw from Curve is very close to the amount we actually withdraw (by artificially
        // forcing CBM to withdraw).
        vm.startPrank(address(chickenBondManager));
        uint256 curveShares = yearnCurveVault.withdraw(yearnCurveVault.balanceOf(address(chickenBondManager)));
        uint256 cbmLUSDBalBeforeCurveWithdraw = lusdToken.balanceOf(address(chickenBondManager));
        curvePool.remove_liquidity_one_coin(curveShares, 0, 0);
        uint256 cbmLUSDBalAfterCurveWithdraw = lusdToken.balanceOf(address(chickenBondManager));
        uint256 lusdWithdrawalFromCurve = cbmLUSDBalAfterCurveWithdraw - cbmLUSDBalBeforeCurveWithdraw;
        uint256 relativeCurveWithdrawalDelta = abs(lusdWithdrawalFromCurve, cbmCurveIncrease) * 1e18 / cbmCurveIncrease;

        // Confirm that a forced Curve withdrawal results in a LUSD withdrawal that is within 0.01%
        //  of the calculated withdrawal amount
        assertLt(relativeCurveWithdrawalDelta, 1e14);

        uint256 lossRelativeToCurvePool = diffOrZero(CurveBalanceIncrease, cbmCurveIncrease) * 1e18 / CurveBalanceIncrease;
        uint256 lossRelativeToYearnVault = diffOrZero(cbmyearnSPVaultDecrease, yearnSPVaultBalanceDecrease) * 1e18 / yearnSPVaultBalanceDecrease;

        // Curve shifting loss can be up to ~1% of the shifted amount, due to Curve pool share calculation
        assertLt(lossRelativeToCurvePool, 1e16);
        // Yearn LUSD vault shifting loss is much lower
        assertLt(lossRelativeToYearnVault, 1e3);
    }

    function testShiftLUSDFromSPToCurveChangesPermanentBucketsBySimilarAmount(uint bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get permanent LUSD in both pools before
        uint256 permanentLUSDInCurve_1 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInSP_1 = chickenBondManager.getPermanentLUSDInSP();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;

        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 permanentLUSDInCurve_2 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInSP_2 = chickenBondManager.getPermanentLUSDInSP();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 permanentLUSDYearnDecrease_1 = permanentLUSDInSP_1 - permanentLUSDInSP_2;
        uint256 permanentLUSDCurveIncrease_1 = permanentLUSDInCurve_2 - permanentLUSDInCurve_1;

        uint256 relativePermanentLoss = diffOrZero(permanentLUSDYearnDecrease_1, permanentLUSDCurveIncrease_1) * 1e18 / (permanentLUSDInSP_1 + permanentLUSDInCurve_1);
        // Check that any discrepancy between the permanent SP decrease and the permanent Curve increase from shifting is <1% of
        // the initial permanent LUSD in the SP
        // Appears to be high due the loss upon Curve deposit.
        assertLt(relativePermanentLoss, 1e16);
    }

    function testShiftLUSDFromSPToCurveChangesAcquiredBucketsBySimilarAmount(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get permanent LUSD in both pools before
        uint256 acquiredLUSDInCurve_1 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInSP_1 = chickenBondManager.getAcquiredLUSDInSP();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;

        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 acquiredLUSDInCurve_2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInSP_2 = chickenBondManager.getAcquiredLUSDInSP();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 acquiredLUSDYearnDecrease_1 = acquiredLUSDInSP_1 - acquiredLUSDInSP_2;
        uint256 acquiredLUSDCurveIncrease_1 = acquiredLUSDInCurve_2 - acquiredLUSDInCurve_1;

        uint256 relativeAcquiredLoss = diffOrZero(acquiredLUSDYearnDecrease_1, acquiredLUSDCurveIncrease_1) * 1e18 / acquiredLUSDInSP_1 + acquiredLUSDInCurve_1;

        // Check that any discrepancy between the acquired SP decrease and the acquired Curve increase from shifting is <0.01% of
        // the initial acquired LUSD in the SP
        assertLt(relativeAcquiredLoss, 1e14);
    }

    // Actual Yearn and Curve balance tests
    // function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInSPAndCurveVault() public {}

    // function testShiftLUSDFromSPToCurveDecreasebLUSDInSP() public {}
    // function testShiftLUSDFromSPToCurveIncreaseLUSDInCurve() public {}

    // function testFailShiftLUSDFromSPToCurveWhen0LUSDInSP() public {}
    // function testShiftLUSDFromSPToCurveRevertsWithZeroLUSDinSP() public {}


    // --- shiftLUSDFromCurveToSP tests ---


    function testShiftLUSDFromCurveToSPRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Attempt to shift 0 LUSD
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.shiftLUSDFromCurveToSP(0);
    }

    function testShiftLUSDFromCurveToSPRevertsWhenCurvePriceGreaterThan1() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);

        // Check spot price is > 1.0
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // Attempt to shift 10% of owned LUSD
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        // Try to shift the LUSD
        vm.expectRevert("CBM: Curve spot must be < 1.0 before Curve->SP shift");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    // TODO: refactor this test to be more robust to specific Curve mainnet state. Currently sometimes fails.
    // function testShiftLUSDFromCurveToSPRevertsWhenShiftWouldRaiseCurvePriceAbove1() public {
    //     vm.startPrank(yearnGovernanceAddress);
    //     yearnSPVault.setDepositLimit(1e27);
    //     vm.stopPrank();

    //     // A creates bond
    //     uint256 bondAmount = 500_000_000e18; // 500m

    //     tip(address(lusdToken), A, bondAmount);
    //     createBondForUser(A, bondAmount);
    //     uint256 A_bondID = bondNFT.totalMinted();

    //     // 1 year passes
    //     vm.warp(block.timestamp + 365 days);

    //     // A chickens in
    //     vm.startPrank(A);
    //     chickenBondManager.chickenIn(A_bondID);
    //     vm.stopPrank();

    //     makeCurveSpotPriceAbove1(300_000_000e18);
    //     // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
    //     console.log("A");
    //     console.log(curvePool.get_dy_underlying(0, 1, 1e18), "Curve price A");
    //     shiftFractionFromSPToCurve(30);

    //     console.log("B");
    //     makeCurveSpotPriceBelow1(50_000_000e18);
    //     console.log("C");
    //     console.log(curvePool.get_dy_underlying(0, 1, 1e18), "Curve price before shift Curve->SP test");
    //     // Now, attempt to shift an amount which would raise the price back above 1.0, and expect it to fail
    //     vm.expectRevert("CBM: Curve->SP shift must increase spot price to <= 1.0");
    //     chickenBondManager.shiftLUSDFromCurveToSP(5_000_000e18);
    //     console.log(curvePool.get_dy_underlying(0, 1, 1e18), "Curve price after final shift Curve->SP");
    // }

    function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertApproximatelyEqual(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 2e4);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalPermanentLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total permanent LUSD > 0
        uint256 totalPermanentLUSD = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();
        assertTrue(totalPermanentLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // get CBM's recorded total permanent LUSD before
        uint256 totalPermanentLUSDBefore = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();
        assertTrue(totalPermanentLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalPermanentLUSDAfter = chickenBondManager.getPermanentLUSDInSP() + chickenBondManager.getPermanentLUSDInCurve();
        assertApproximatelyEqual(totalPermanentLUSDAfter, totalPermanentLUSDBefore, 2e4);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMPendingLUSDTracker() public {// A creates bond
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check pending LUSD After has not changed
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers

    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInSPTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0, "total ac. lusd not < 0 after chicken in");

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        //uint256 permanentYearnAfterShift = chickenBondManager.getPermanentLUSDInSP();
        //uint256 permanentCurveAfterShift = chickenBondManager.getPermanentLUSDInCurve();
        assertGt(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        assertGt(chickenBondManager.getAcquiredLUSDInSP(), 0);

        // Get acquired LUSD in Yearn Before
        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();
        assertGt(acquiredLUSDInSPBefore, 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve

        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check acquired LUSD in Yearn Increases
        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();

        assertGt(acquiredLUSDInSPAfter, acquiredLUSDInSPBefore, "ac. LUSD before and after shift doesn't change");
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInSPTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get LUSD in Yearn Before
        uint256 lusdInSPBefore = chickenBondManager.calcTotalYearnSPVaultShareValue();

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check LUSD in Yearn Increases
        uint256 lusdInSPAfter = chickenBondManager.calcTotalYearnSPVaultShareValue();
        assertTrue(lusdInSPAfter > lusdInSPBefore);
    }


    function testShiftLUSDFromCurveToSPDecreasesCBMLUSDInCurveTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get acquired LUSD in Curve Before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check LUSD in Curve Decreases
        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(acquiredLUSDInCurveAfter < acquiredLUSDInCurveBefore);
    }

    function testShiftLUSDFromCurveToSPLosesMinimalLUSD(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // uint256 bondAmount = 1000000000000000001;

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get the total LUSD in Yearn and Curve before
        uint256 cbmLUSDInSPBefore = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        // Get actual SP and Curve pool LUSD Balances before
        uint256 yearnSPVaultBalanceBefore =  lusdToken.balanceOf(address(yearnSPVault));
        uint256 CurveBalanceBefore = lusdToken.balanceOf(address(curvePool));

        // Shift Curve->SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // Shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Get the total LUSD in Yearn and Curve after
        uint256 cbmLUSDInSPAfter = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();

        // Get actual SP and Curve pool LUSD Balances after
        uint256 yearnSPVaultBalanceAfter = lusdToken.balanceOf(address(yearnSPVault));
        uint256 CurveBalanceAfter = lusdToken.balanceOf(address(curvePool));

        // Check Yearn LUSD vault increases
        assertGt(cbmLUSDInSPAfter, cbmLUSDInSPBefore);
        assertGt(yearnSPVaultBalanceAfter, yearnSPVaultBalanceBefore);
        // Check Curve pool decreases
        assertLt(cbmLUSDInCurveAfter, cbmLUSDInCurveBefore);
        assertLt(CurveBalanceAfter, CurveBalanceBefore);

        uint256 cbmyearnSPVaultIncrease = cbmLUSDInSPAfter - cbmLUSDInSPBefore; // Yearn LUSD vault increases
        uint256 cbmCurveDecrease = cbmLUSDInCurveBefore - cbmLUSDInCurveAfter; // Curve decreases

        uint256 yearnSPVaultBalanceIncrease = yearnSPVaultBalanceAfter - yearnSPVaultBalanceBefore;
        uint256 CurveBalanceDecrease = CurveBalanceBefore - CurveBalanceAfter;

        /*Calculate the relative losses, if there are any.
        * Our relative Curve loss is positive if CBM has lost more than Curve has lost.
        * Our relative Yearn LUSD loss is positive if Yearn LUSD vault has gained more than CBM has gained.
        */
        uint256 lossRelativeToCurvePool = diffOrZero(cbmCurveDecrease, CurveBalanceDecrease) * 1e18 / CurveBalanceDecrease;
        uint256 lossRelativeToYearnLUSDVault = diffOrZero(yearnSPVaultBalanceIncrease, cbmyearnSPVaultIncrease) * 1e18 / yearnSPVaultBalanceIncrease;

        // Check that both deltas are < 1 million'th tiny when shifting Curve->SP
        assertLt(lossRelativeToCurvePool, 1e12);
        assertLt(lossRelativeToYearnLUSDVault, 1e12);
    }

    function testShiftLUSDFromCurveToSPChangesPermanentBucketsBySimilarAmount(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // uint256 bondAmount = 10e18;

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get permanent LUSD in both pools before
        uint256 permanentLUSDInCurve_1 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInSP_1 = chickenBondManager.getPermanentLUSDInSP();
        assertGt(permanentLUSDInCurve_1, 0);
        assertGt(permanentLUSDInSP_1, 0);

        // Shift 10% of owned LUSD in Curve;
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10;
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 permanentLUSDInCurve_2 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInSP_2 = chickenBondManager.getPermanentLUSDInSP();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 permanentLUSDYearnIncrease_1 = permanentLUSDInSP_2 - permanentLUSDInSP_1;
        uint256 permanentLUSDCurveDecrease_1 = permanentLUSDInCurve_1 - permanentLUSDInCurve_2;

        uint256 relativePermanentLoss = diffOrZero(permanentLUSDCurveDecrease_1, permanentLUSDYearnIncrease_1) * 1e18 / (permanentLUSDInCurve_1 + permanentLUSDInSP_1);

       // Check that any relative loss in the permanent bucket from shifting Curve->SP is less than 1 million'th of total permanent LUSD
        assertLt(relativePermanentLoss, 1e12);
    }

    function testShiftLUSDFromCurveToSPChangesAcquiredBucketsBySimilarAmount(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get acquired LUSD in both pools before
        uint256 acquiredLUSDInCurve_1 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInSP_1 = chickenBondManager.getAcquiredLUSDInSP();
        assertGt(acquiredLUSDInCurve_1, 0);
        assertGt(acquiredLUSDInSP_1, 0);

        // Shift 10% of owned LUSD in Curve
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10;
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 acquiredLUSDInCurve_2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInSP_2 = chickenBondManager.getAcquiredLUSDInSP();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 acquiredLUSDYearnIncrease_1 = acquiredLUSDInSP_2 - acquiredLUSDInSP_1;
        uint256 acquiredLUSDCurveDecrease_1 = acquiredLUSDInCurve_1 - acquiredLUSDInCurve_2;

       uint256 relativeAcquiredLoss = diffOrZero(acquiredLUSDCurveDecrease_1, acquiredLUSDYearnIncrease_1) * 1e18 / (acquiredLUSDInSP_1 + acquiredLUSDInCurve_1);

        // Check that any relative loss in the acquired bucket from shifting Curve->SP is less than 1 billion'th of total acquired LUSD
        assertLt(relativeAcquiredLoss, 1e12);
    }

    // --- Curve withdrawal loss tests ---

    function testCurveImmediateLUSDDepositAndWithdrawalLossIsBounded(uint256 _depositAmount) public {
        // // Set Curve spot price to >1.0
        makeCurveSpotPriceAbove1(75_000_000e18);

        vm.assume(_depositAmount < 1e27 && _depositAmount > 1e18); // deposit in range [1, 1bil] LUSD

        // uint256 _depositAmount = 10e18;

        // Tip CBM some LUSD
        tip(address(lusdToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to Curve, as CBM
        vm.startPrank(address(chickenBondManager));
        curvePool.add_liquidity([_depositAmount, 0], 0);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Artifiiually withdraw all the share value as CBM
        uint256 cbmShares = curvePool.balanceOf(address(chickenBondManager));
        curvePool.remove_liquidity_one_coin(cbmShares, 0, 0);

        uint256 cbmLUSDBalAfter = lusdToken.balanceOf(address(chickenBondManager));
        uint256 curveRelativeDepositLoss = diffOrZero(_depositAmount, cbmLUSDBalAfter) * 1e18 / _depositAmount;

        // Check that simple Curve LUSD deposit->withdraw loses between [0.01%, 1%] of initial deposit.
        assertLt(curveRelativeDepositLoss, 1e15);
        assertGt(curveRelativeDepositLoss, 1e14);
    }

    function testCurveImmediate3CRVDepositAndWithdrawalLossIsBounded(uint256 _depositAmount) public {
        // Set Curve spot price to >1.0
        makeCurveSpotPriceAbove1(100_000_000e18);

        vm.assume(_depositAmount < 1e27 && _depositAmount > 1e18); // deposit in range [1, 1bil] LUSD

        // uint256 _depositAmount = 10e18;

        // Tip CBM some 3CRV
        tip(address(_3crvToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to Curve, as CBM
        //uint256 cbm3CRVBalBeforeDep = _3crvToken.balanceOf(address(chickenBondManager));
        vm.startPrank(address(chickenBondManager));

        _3crvToken.approve(address(curvePool), _depositAmount);
        curvePool.add_liquidity([0, _depositAmount], 0); // 2nd array slot is 3CRV token amount
        uint256 cbm3CRVBalBefore = _3crvToken.balanceOf(address(chickenBondManager));
        assertEq(cbm3CRVBalBefore, 0);

        // Artifiiually withdraw all the share value as CBM
        uint256 cbmShares = curvePool.balanceOf(address(chickenBondManager));
        curvePool.remove_liquidity_one_coin(cbmShares, 1, 0);

        uint256 cbm3CRVBalAfter = _3crvToken.balanceOf(address(chickenBondManager));
        uint256 curveRelativeDepositLoss = diffOrZero(_depositAmount, cbm3CRVBalAfter) * 1e18 / _depositAmount;

        // Check that simple Curve 3CRV deposit->withdraw loses  <0.1% of initial deposit.
        assertLt(curveRelativeDepositLoss, 1e15);
    }

    function testCurveImmediateProportionalDepositAndWithdrawalLossIsBounded(uint256 _depositMagnitude) public {
        // Set Curve spot price to >1.0
        makeCurveSpotPriceAbove1(100_000_000e18);

        vm.assume(_depositMagnitude < 1e27 && _depositMagnitude >= 1e18); // deposit magnitude in range [1, 1bil]

        uint256 curve3CRVSpot = curvePool.get_dy_underlying(1, 0, 1e18);

        // Choose deposit amounts in proportion to current spot price, in order to keep it constant
        //uint256 _depositMagnitude = 10e18;
        // multiply by the lusd-per-3crv
        uint256 _lusdDepositAmount =  curve3CRVSpot * _depositMagnitude / 1e18;
        uint256 _3crvDepositAmount = _depositMagnitude;

        uint256 total3CRVValueBefore = _depositMagnitude * 2;

        // Tip CBM some LUSD and 3CRV
        tip(address(lusdToken), address(chickenBondManager), _lusdDepositAmount);
        tip(address(_3crvToken), address(chickenBondManager), _3crvDepositAmount);

        // Artificially deposit LUSD to Curve, as CBM
        vm.startPrank(address(chickenBondManager));

        lusdToken.approve(address(curvePool), _lusdDepositAmount);
        _3crvToken.approve(address(curvePool), _3crvDepositAmount);
        curvePool.add_liquidity([_lusdDepositAmount, _3crvDepositAmount], 0); // deposit both tokens

        uint256 cbmLUSDBalBefore = lusdToken.balanceOf(address(chickenBondManager));
        uint256 cbm3CRVBalBefore = _3crvToken.balanceOf(address(chickenBondManager));
        assertEq(cbmLUSDBalBefore, 0);
        assertEq(cbm3CRVBalBefore, 0);

        // Artificially withdraw all the share value as CBM
        uint256 cbmShares = curvePool.balanceOf(address(chickenBondManager));
        curvePool.remove_liquidity(cbmShares, [uint256(0), uint256(0)]); // receive both LUSD and 3CRV, no minimums

        uint256 cbmLUSDBalAfter = lusdToken.balanceOf(address(chickenBondManager));
        uint256 cbm3CRVBalAfter = _3crvToken.balanceOf(address(chickenBondManager));

        uint256 curve3CRVSpotAfter = curvePool.get_dy_underlying(1, 0, 1e18);

        // divide the LUSD by the LUSD-per-3CRV, to get the value of the LUSD in 3CRV
        uint256 total3CRVValueAfter = cbm3CRVBalAfter + (cbmLUSDBalAfter * 1e18 /  curve3CRVSpotAfter);

        uint256 total3CRVRelativeDepositLoss = diffOrZero(total3CRVValueBefore, total3CRVValueAfter) * 1e18 / total3CRVValueBefore;

        // Check that a proportional Curve 3CRV and LUSD deposit->withdraw loses between [0.01%, 1%] of initial deposit.
        assertLt(total3CRVRelativeDepositLoss, 1e16);
        assertGt(total3CRVRelativeDepositLoss, 1e14);
    }

    function loopOverCurveLUSDDepositSizes(int steps) public {
        uint256 depositAmount = 1e18;
        uint256 stepMultiplier = 10;

        // Loop over deposit sizes
        int step;
        while (step < steps) {
            // Tip CBM some LUSD
            tip(address(lusdToken), address(chickenBondManager), depositAmount);

            // Artificially deposit LUSD to Curve, as CBM
            vm.startPrank(address(chickenBondManager));
            curvePool.add_liquidity([depositAmount, 0], 0);

            assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

            // Artificially withdraw all the share value as CBM
            uint256 cbmSharesBefore = curvePool.balanceOf(address(chickenBondManager));
            curvePool.remove_liquidity_one_coin(cbmSharesBefore, 0, 0);
            uint256 cbmSharesAfter = curvePool.balanceOf(address(chickenBondManager));
            assertEq(cbmSharesAfter, 0);

            vm.stopPrank();

            uint256 cbmLUSDBalAfter = lusdToken.balanceOf(address(chickenBondManager));
            uint256 curveRelativeDepositLoss = diffOrZero(depositAmount, cbmLUSDBalAfter) * 1e18 / depositAmount;

            console.log(depositAmount / 1e18);
            console.log(curveRelativeDepositLoss);

            depositAmount *= stepMultiplier;
            step++;
        }
    }

    // LUSD deposit, initial curve price above 1
    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceAboveOne1() public {
        makeCurveSpotPriceAbove1(200_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceAboveOne2() public {
        makeCurveSpotPriceAbove1(500_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceAboveOne3() public {
        makeCurveSpotPriceAbove1(1000_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    // LUSD deposit, initial curve price below 1
    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceBelowOne1() public {
        makeCurveSpotPriceBelow1(200_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceBelowOne2() public {
        makeCurveSpotPriceBelow1(500_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    function testCurveImmediateLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceBelowOne3() public {
        makeCurveSpotPriceBelow1(1000_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverCurveLUSDDepositSizes(10);
    }

    struct Vars {
            uint256 _depositMagnitude;
            uint256 stepMultiplier;
            int steps;
            uint256 _lusdDepositAmount;
            uint256 _3crvDepositAmount;
            uint256 LUSDto3CRVDepositRatioBefore;
            uint256 LUSDto3CRVBalRatioAfter;
        }

    function loopOverProportionalDepositSizes(int steps) public {
        Vars memory vars;
        vars._depositMagnitude = 1e18;
        vars.stepMultiplier = 10;
        vars.steps = 10;
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");

        uint256 curve3CRVSpot = curvePool.get_dy_underlying(1, 0, 1e18);

        vm.startPrank(address(chickenBondManager));

        for (int i = 1; i <= steps; i++) {

            // multiply by the lusd-per-3crv
            vars._lusdDepositAmount =  curve3CRVSpot * vars._depositMagnitude / 1e18;
            vars._3crvDepositAmount = vars._depositMagnitude;

            uint256 total3CRVValueBefore = vars._depositMagnitude * 2;

            // Tip CBM some LUSD and 3CRV
            tip(address(lusdToken), address(chickenBondManager), vars._lusdDepositAmount);
            tip(address(_3crvToken), address(chickenBondManager), vars._3crvDepositAmount);
            vars.LUSDto3CRVDepositRatioBefore = vars._lusdDepositAmount * 1e18 / vars._3crvDepositAmount;
            console.log(vars.LUSDto3CRVDepositRatioBefore, "lusd to 3crv deposit ratio");

            lusdToken.approve(address(curvePool), vars._lusdDepositAmount);
            _3crvToken.approve(address(curvePool), vars._3crvDepositAmount);
            curvePool.add_liquidity([vars._lusdDepositAmount, vars._3crvDepositAmount], 0); // deposit both tokens

            uint256 cbmLUSDBalBefore = lusdToken.balanceOf(address(chickenBondManager));
            uint256 cbm3CRVBalBefore = _3crvToken.balanceOf(address(chickenBondManager));
            assertEq(cbmLUSDBalBefore, 0);
            assertEq(cbm3CRVBalBefore, 0);

            // Artificially withdraw all the share value as CBM
            uint256 cbmShares = curvePool.balanceOf(address(chickenBondManager));
            curvePool.remove_liquidity(cbmShares, [uint256(0), uint256(0)]); // receive both LUSD and 3CRV, no minimums

            uint256 cbmLUSDBalAfter = lusdToken.balanceOf(address(chickenBondManager));
            uint256 cbm3CRVBalAfter = _3crvToken.balanceOf(address(chickenBondManager));
            vars.LUSDto3CRVBalRatioAfter = cbmLUSDBalAfter * 1e18 / cbm3CRVBalAfter;
            console.log(vars.LUSDto3CRVBalRatioAfter, "lUSD to 3crv balance ratio");
            uint256 curve3CRVSpotAfter = curvePool.get_dy_underlying(1, 0, 1e18);

            // divide the LUSD by the LUSD-per-3CRV, to get the value of the LUSD in 3CRV
            uint256 total3CRVValueAfter = cbm3CRVBalAfter + (cbmLUSDBalAfter * 1e18 /  curve3CRVSpotAfter);

            uint256 total3CRVRelativeDepositLoss = diffOrZero(total3CRVValueBefore, total3CRVValueAfter) * 1e18 / total3CRVValueBefore;

            console.log(vars._depositMagnitude / 1e18);
            console.log(total3CRVRelativeDepositLoss);

            vars._depositMagnitude *= vars.stepMultiplier;
        }
    }

    function testCurveImmediateProportionalLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceAboveOne1() public {
        makeCurveSpotPriceAbove1(50_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverProportionalDepositSizes(10);
    }

     function testCurveImmediateProportionalLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceAboveOne2() public {
        makeCurveSpotPriceAbove1(1000_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverProportionalDepositSizes(10);
    }

    function testCurveImmediateProportionalLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceBelowOne1() public {
        makeCurveSpotPriceBelow1(50_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverProportionalDepositSizes(10);
    }

     function testCurveImmediateProportionalLUSDDepositAndWithdrawalLossVariesWithDepositSize_PriceBelowOne2() public {
        makeCurveSpotPriceAbove1(1000_000_000e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curve spot price before");
        loopOverProportionalDepositSizes(10);
    }

    // --- Fee share test ---

    function testSendFeeShareCallableOnlyByYearnGov() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        tip(address(lusdToken), yearnGovernanceAddress, 37e18);
        vm.startPrank(yearnGovernanceAddress);
        lusdToken.approve(address(chickenBondManager), 37e18);
        vm.stopPrank();

        // Reverts for bLUSD holder
        vm.startPrank(A);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        // Reverts for current bonder
        vm.startPrank(C);
        vm.expectRevert("CBM: Only Yearn Governance can call");
         chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        // Reverts for random address
        vm.startPrank(D);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        // reverts for yearn non-gov addresses
        address YEARN_STRATEGIST = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7;
        address YEARN_GUARDIAN = 0x846e211e8ba920B353FB717631C015cf04061Cc9;
        address YEARN_KEEPER = 0xaaa8334B378A8B6D8D37cFfEF6A755394B4C89DF;

        vm.startPrank(YEARN_STRATEGIST);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        vm.startPrank(YEARN_GUARDIAN);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        vm.startPrank(YEARN_KEEPER);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.sendFeeShare(37e18);
        vm.stopPrank();

        // Succeeds for Yearn governance
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.sendFeeShare(37e18);
    }

    function testSendFeeShareInMigrationModeReverts() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        uint256 feeShare = 37e18;

        tip(address(lusdToken), yearnGovernanceAddress, feeShare);

        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        lusdToken.approve(address(chickenBondManager), feeShare);

        vm.expectRevert("CBM: Receive fee share only in normal mode");
        chickenBondManager.sendFeeShare(feeShare);
    }

    function testSendFeeShareInNormalModeIncreasesAcquiredLUSDInSP() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        uint256 feeShare = 37e18;

        tip(address(lusdToken), yearnGovernanceAddress, feeShare);
        vm.startPrank(yearnGovernanceAddress);
        lusdToken.approve(address(chickenBondManager), feeShare);
        vm.stopPrank();

        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();
        uint256 permanentLUSDInSPBefore = chickenBondManager.getPermanentLUSDInSP();
        uint256 pendingLUSDInSPBefore = chickenBondManager.totalPendingLUSD();
        uint256 ownedLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        // Succeeds for Yearn governance
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.sendFeeShare(feeShare);

        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();
        uint256 permanentLUSDInSPAfter = chickenBondManager.getPermanentLUSDInSP();
        uint256 pendingLUSDInSPAfter = chickenBondManager.totalPendingLUSD();
        uint256 ownedLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();

        //Check acquired LUSD In SP increased by correct amount
        uint256 tolerance = feeShare / 1e9;  // relative error tolerance of 1e-9
        assertApproximatelyEqual(acquiredLUSDInSPAfter - acquiredLUSDInSPBefore, feeShare, tolerance);

        // Other buckets don't change
        assertEq(permanentLUSDInSPAfter, permanentLUSDInSPBefore);
        assertEq(pendingLUSDInSPAfter, pendingLUSDInSPBefore);
        assertEq(ownedLUSDInCurveAfter, ownedLUSDInCurveBefore);
    }
}
