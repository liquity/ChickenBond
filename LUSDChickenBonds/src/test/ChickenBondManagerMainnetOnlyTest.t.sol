pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";
import "../Interfaces/StrategyAPI.sol";


contract ChickenBondManagerMainnetOnlyTest is BaseTest, MainnetTestSetup {

    function _generateBAMMYield(uint256 _yieldAmount, address _user) internal {
        (uint256 ethAmount,) = bammSPVault.getSwapEthAmount(_yieldAmount);

        deal(address(lusdToken), address(_user), lusdToken.balanceOf(address(_user)) + _yieldAmount);
        vm.deal(address(bammSPVault), ethAmount);

        vm.startPrank(_user);
        lusdToken.approve(address(bammSPVault), _yieldAmount);
        bammSPVault.swap(_yieldAmount, 0, payable(_user));
        vm.stopPrank();

        chickenBondManager.updateBAMMDebt();
    }

    function _generateCurveRevenue() internal {
        vm.startPrank(A);
        // Approve tokens
        lusdToken.approve(address(curvePool), type(uint256).max);
        _3crvToken.approve(address(curvePool), type(uint256).max);

        uint256 lusdAmount = 1e25;
        uint256 _3CRVAmount;
        // fund account
        deal(address(lusdToken), A, lusdAmount);

        // swap back and forth several times
        for (uint256 i = 0; i < 2; i++){
            _3CRVAmount = curvePool.exchange(0, 1, lusdAmount, 0, A);
            lusdAmount = curvePool.exchange(1, 0, _3CRVAmount, 0, A);
        }
        vm.stopPrank();
    }

    function _curveHarvestAndFastForward() internal returns (uint256) {
        uint256 prevValue = chickenBondManager.getTotalLUSDInCurve();
        _generateCurveRevenue();

        // harvest from both strategies in the vault
        for (uint256 i = 0; i < 2; i++) {
            // get strategy
            address strategy = yearnCurveVault.withdrawalQueue(i);
            if (strategy == ZERO_ADDRESS) { continue; }

            // get keeper
            address keeper = StrategyAPI(strategy).keeper();

            // harvest
            vm.startPrank(keeper);
            StrategyAPI(strategy).harvest();
            vm.stopPrank();
        }

        // some time passes to unlock profits
        vm.warp(block.timestamp + 30 days);

        uint256 newValue = chickenBondManager.getTotalLUSDInCurve();
        uint256 curveYield = newValue - prevValue;

        return curveYield;
    }

    // --- chickening in when sTOKEN supply is zero ---

    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield, C);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + chickenInFeeAmount,
            100,
            "Balance of rewards contract doesn't match"
        );

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), chickenInFeeAmount, 1, "Balance of rewards contract doesn't match");

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionAlmostDepletionAndSPHarvestTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield, C);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + chickenInFeeAmount,
            100,
            "Balance of rewards contract after A's chicken-in doesn't match"
        );

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_REDEEM);

        // A redeems full
        vm.startPrank(A);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A) - MIN_BLUSD_SUPPLY, 0);
        vm.stopPrank();

        // Confirm total bLUSD supply is > MIN
        assertGe(bLUSDToken.totalSupply(), MIN_BLUSD_SUPPLY, "bLUSD supply not greater or equal than min after redemption");

        // B.Protocol LUSD Vault gets some yield
        uint256 secondYield = 2e18;
        _generateBAMMYield(secondYield, C);

        // B chickens in
        vm.startPrank(B);
        uint256 accruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + 2 * chickenInFeeAmount,
            20,
            "Balance of rewards contract after B's chicken-in doesn't match"
        );

        // check CBM holds no LUSD
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0, "cbm holds zero lusd");

        // check bLUSD B balance
        assertEq(bLUSDToken.balanceOf(B), accruedBLUSD_B, "bLUSD balance of B doesn't match");
    }

    function testFirstChickenInAfterRedemptionAlmostDepletionAndCurveHarvestTransfersToRewardsContract() external {
        uint256 bondAmount1 = 1000e18;
        uint256 bondAmount2 = 100e18;
        deal(address(lusdToken), A, bondAmount1 + bondAmount2);

        // create bond
        uint256 A_bondID = createBondForUser(A, bondAmount1);

        // wait 100 days
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();


        _startShiftCountdownAndWarpInsideWindow();

        // shift 50% to Curve
        shiftFractionFromSPToCurve(2);

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_REDEEM);

        uint256 initialPermanentLUSD = chickenBondManager.getPermanentLUSD();

        // A redeems full
        uint256 redeemAmount = bLUSDToken.balanceOf(A) - MIN_BLUSD_SUPPLY;
        uint256 redemptionFeeAmount = redeemAmount * chickenBondManager.calcRedemptionFeePercentage(redeemAmount * 1e18 / bLUSDToken.balanceOf(A)) / 1e18 * chickenBondManager.calcSystemBackingRatio() / 1e18;
        vm.startPrank(A);
        chickenBondManager.redeem(redeemAmount, 0);
        vm.stopPrank();
        uint256 acquiredLUSDAfterRedemption = chickenBondManager.getTotalAcquiredLUSD();

        // create bond
        A_bondID = createBondForUser(A, bondAmount2);

        // wait 100 days more
        vm.warp(block.timestamp + 100 days);

        // harvest curve and fast forward time to unlock profits
        uint256 curveYield = _curveHarvestAndFastForward();
        assertGt(curveYield, 0, "Yield generated in Curve vault should be greater than zero");

        // A chickens in
        uint256 lusdToAcquire2 = chickenBondManager.getLUSDToAcquire(A_bondID);

        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Checks
        // After withdrawing from initial yield from Curve to transfer it to Rewards contract,
        // the withdrawal itself has to pay a fee to the pool, some of which is captured by the
        // remaining pool share of CBM, thus results are not exact

        // Backing ratio
        assertApproximatelyEqual(
            chickenBondManager.calcSystemBackingRatio(),
            acquiredLUSDAfterRedemption + curveYield,
            1000,
            "Backing ratio mismatch"
        );

        // Acquired
        assertApproximatelyEqual(
            chickenBondManager.getTotalAcquiredLUSD(),
            acquiredLUSDAfterRedemption + lusdToAcquire2 + curveYield,
            100,
            "Acquired LUSD mismatch"
        );

        // Permanent
        assertApproximatelyEqual(
            chickenBondManager.getPermanentLUSD(),
            initialPermanentLUSD + redemptionFeeAmount + _getAmountMinusChickenInFee(bondAmount2) - lusdToAcquire2,
            1000,
            "Permanent LUSD mismatch"
        );

        // Balance in rewards contract
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            _getChickenInFeeForAmount(bondAmount1) + _getChickenInFeeForAmount(bondAmount2),
            100,
            "Rewards contract balance mismatch"
        );
    }

    // --- redemption tests ---

    function testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction(uint256 redemptionFraction) public {
        // Fraction between 1 billion'th, and 100%.  If amount is too tiny, redemption can revert due to attempts to
        // withdraw 0 LUSDfrom Yearn (due to rounding in share calc).
        redemptionFraction = coerce(redemptionFraction, 1e9, 99e16);

        // Fee goes into permanent, so the entire redeemed fraction leaves acquired
        uint256 expectedFractionRemainingAfterRedemption = 1e18 - redemptionFraction;

        // A creates bond
        uint256 bondAmount = 600e18;

        createBondForUser(A, bondAmount);

        // time passes
        vm.warp(block.timestamp + 365 days);

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalSupply();
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

        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B), "A should transfer all bLUSD");
        assertEq(bLUSDToken.totalSupply(), bLUSDToken.balanceOf(B), "B should own the total supply");

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_REDEEM);

        // Get acquired LUSD in Curve before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        assertGt(acquiredLUSDInCurveBefore, 0, "Acquired in Curve should be greater than zero");

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(bLUSDToRedeem, bLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(bLUSDToRedeem, 0);
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

    function testShiftLUSDFromSPToCurveRevertsWhenCountdownNeverStarted() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsDuringCountdown() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);


        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to middle of shifter countdown
        vm.warp(countdownStartTime + SHIFTER_DELAY / 2);
         
        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // fast forward to last second of shifter countdown
        vm.warp(countdownStartTime + SHIFTER_DELAY - 1);

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsAfterShiftWindowCloses() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to end of shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW);
         
        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // fast forward to a timestamp after shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW + 17 days);

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveSucceedsDuringShiftWindow() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);
        uint256 lusdInCurve1 = chickenBondManager.getOwnedLUSDInCurve();
        assertEq(lusdInCurve1, 0);

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to middle of shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW / 2);
         
        // Shift LUSD SP->Curve and check LUSD in Curve increases
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        uint256 lusdInCurve2 = chickenBondManager.getOwnedLUSDInCurve();
        assertGt(lusdInCurve2, lusdInCurve1);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenZeroBLUSDSupply() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        bondNFT.totalSupply();

        // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield, C);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

         // Attempt to shift LUSD
        vm.expectRevert("CBM: bLUSD Supply must be > 0 upon shifting");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsBeforeEndOfShiftBootstrapPeriod() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // CI bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);
       
        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

       _startShiftCountdownAndWarpInsideWindow();

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        
        // Warp to the time that is half way through the shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT / 2); 
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Fastforward to 1 second before the shifter boostrap period ends
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT - 1); 
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveSucceedsAfterEndOfShiftBootstrapPeriod() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // CI bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);
       
        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        uint256 lusdInCurve_1 = chickenBondManager.getOwnedLUSDInCurve();
        assertEq(lusdInCurve_1, 0);
        
        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        // Check shift to Curve succeeds
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        uint256 lusdInCurve_2 = chickenBondManager.getOwnedLUSDInCurve();
        assertGt(lusdInCurve_2, lusdInCurve_1);

        // Warp to some time after the end of bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT + 17 days);

        _startShiftCountdownAndWarpInsideWindow();

        // Check second shift to Curve succeeds
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        uint256 lusdInCurve_3 = chickenBondManager.getOwnedLUSDInCurve();
        assertGt(lusdInCurve_3, lusdInCurve_2);
    }

    function testShiftLUSDFromSPToCurveRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceBelow1(200_000_000e18);

        // Attempt to shift 10% of acquired LUSD in Yearn
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        // Try to shift the LUSD
        vm.expectRevert("CBM: LUSD:3CRV exchange rate must be over the deposit threshold before SP->Curve shift");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenShiftWouldDropCurvePriceBelow1() public {
        // A creates bond
        uint256 bondAmount = 500_000_000e18; // 500m

        deal(address(lusdToken), A, bondAmount);
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);
        _startShiftCountdownAndWarpInsideWindow();

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
        vm.expectRevert("CBM: SP->Curve shift must decrease LUSD:3CRV exchange rate to a value above the deposit threshold");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdAmount);
    }

    // CBM system trackers
    function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromSPToCurveSlightlyIncreasesAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 A_bondID = createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in Curve
        shiftFractionFromSPToCurve(10);

        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        uint256 exchangeRateBefore = curvePool.get_dy(0, 1, curveBasePool.get_virtual_price());

        // Shift 10% of LUSD in SP (again, as this time Curve vault was not empty before, so it’s a better check for proportions)
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        uint256 exchangeRateAfter = curvePool.get_dy(0, 1, curveBasePool.get_virtual_price());

        assertGt(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);

        uint256 shiftROI = (totalAcquiredLUSDAfter - totalAcquiredLUSDBefore) * 1e18 / lusdToShift;

        emit log_named_decimal_uint("exchange rate before", exchangeRateBefore, 18);
        emit log_named_decimal_uint("exchange rate after", exchangeRateAfter, 18);
        emit log_named_decimal_uint("shift ROI (%)", shiftROI, 16);

        // The profit of depositing LUSD single-sidedly comes from swapping part of the LUSD to 3CRV
        // at a premium.
        // We made to pool LUSD-light to enable SP => Curve shifting, so more than half of the deposit
        // needs to be swapped to 3CRV. (The exact proportion depends on the price and A factor).
        // Therefore in general, the ROI will be more than half of the premium, but less than the
        // entire premium.
        assertLt(exchangeRateAfter, exchangeRateBefore);
        assertGt(shiftROI, (exchangeRateAfter - 1e18) / 2);
        assertLt(shiftROI, exchangeRateBefore - 1e18);
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalPermanentLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // get CBM's recorded total permanent LUSD before
        uint256 totalPermanentLUSDBefore = chickenBondManager.getPermanentLUSD();
        assertGt(totalPermanentLUSDBefore, 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total permanent LUSD hasn't changed
        uint256 totalPermanentLUSDAfter = chickenBondManager.getPermanentLUSD();
        assertEq(totalPermanentLUSDAfter, totalPermanentLUSDBefore, "Permanent LUSD deviated after 1st shift");

        // Shift 10% of LUSD in SP (again, as this time Curve vault was not empty before, so it’s a better check for proportions)
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total permanent LUSD hasn't changed
        uint256 totalPermanentLUSDAfter2 = chickenBondManager.getPermanentLUSD();
        assertEq(totalPermanentLUSDAfter2, totalPermanentLUSDAfter, "Permanent LUSD deviated after 2nd shift");
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMPendingLUSDTracker() public {
        uint256 bondAmount = MIN_BOND_AMOUNT + 25e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.getPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

       // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check pending LUSD After has not changed
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInSPTracker() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT + 25e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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
        uint256 bondAmount = MIN_BOND_AMOUNT + 25e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get CBM's view of LUSD in Yearn
        (uint256 lusdInSPBefore,,) = bammSPVault.getLUSDValue();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Yearn has decreased
        (uint256 lusdInSPAfter,,) = bammSPVault.getLUSDValue();
        assertTrue(lusdInSPAfter < lusdInSPBefore);
    }

    function testShiftLUSDFromSPToCurveIncreasesCBMLUSDInCurveTracker() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT + 25e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get CBM's view of LUSD in Curve before
        uint256 lusdInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Curve has inccreased
        uint256 lusdInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(lusdInCurveAfter > lusdInCurveBefore);
    }

    function testShiftLUSDFromSPToCurveFailsIfCurveGreaterThanPermanent() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT + 25e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);

        uint256 ownedInSPBefore = chickenBondManager.getOwnedLUSDInSP();

        console.log("Before");
        console.log(chickenBondManager.getOwnedLUSDInSP(), "getOwnedLUSDInSP()");
        console.log(chickenBondManager.getTotalLUSDInCurve(), "getTotalLUSDInCurve()");
        console.log(chickenBondManager.getPermanentLUSD(), "getPermanentLUSD()");
        // Shift permanent + 1
        uint256 permanentLUSD = chickenBondManager.getPermanentLUSD();
        chickenBondManager.shiftLUSDFromSPToCurve(permanentLUSD + 1);
        console.log("After");
        console.log(chickenBondManager.getOwnedLUSDInSP(), "getOwnedLUSDInSP()");
        console.log(chickenBondManager.getTotalLUSDInCurve(), "getTotalLUSDInCurve()");
        console.log(chickenBondManager.getPermanentLUSD(), "getPermanentLUSD()");

        // check amount was clamped
        assertEq(chickenBondManager.getOwnedLUSDInSP(), ownedInSPBefore - permanentLUSD);

        // Now the max is reached, nothing else can be shifted
        vm.expectRevert("CBM: The amount in Curve cannot be greater than the Permanent bucket");
        chickenBondManager.shiftLUSDFromSPToCurve(1);
    }

    // Actual Yearn and Curve balance tests
    // function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInSPAndCurveVault() public {}

    // function testShiftLUSDFromSPToCurveDecreasebLUSDInSP() public {}
    // function testShiftLUSDFromSPToCurveIncreaseLUSDInCurve() public {}

    // function testFailShiftLUSDFromSPToCurveWhen0LUSDInSP() public {}
    // function testShiftLUSDFromSPToCurveRevertsWithZeroLUSDinSP() public {}


    // --- shiftLUSDFromCurveToSP tests ---

    function testShiftLUSDFromCurveToSPRevertsWhenCountdownNeverStarted() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = 10e18;

        // Attempt to shift LUSD Curve->SP
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftLUSDFromCurveToSPRevertsDuringCountdown() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = 10e18;

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to middle of shifter countdown
        vm.warp(countdownStartTime + SHIFTER_DELAY / 2);
         
        // Attempt to shift LUSD Curve -> SP
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // fast forward to last second of shifter countdown
        vm.warp(countdownStartTime + SHIFTER_DELAY - 1);

          // Attempt to shift LUSD Curve -> SP
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftLUSDFromCurveToSPRevertsAfterShiftWindowCloses() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = 10e18;

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to end of shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW);
         
        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // fast forward to a timestamp after shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW + 17 days);

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shift only possible inside shifting window");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftLUSDFromCurveToSPSucceedsDuringShiftWindow() public {
         // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);
        
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);
        uint256 lusdInSP1 = chickenBondManager.getOwnedLUSDInSP();
        assertGt(lusdInSP1, 0);

        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(countdownStartTime, block.timestamp);

        // fast forward to middle of shift window
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW / 2);

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);
         
        // Shift LUSD SP->Curve and check LUSD in Curve increases
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
        uint256 lusdInSP2 = chickenBondManager.getOwnedLUSDInSP();
        assertGt(lusdInSP2, lusdInSP1);
    }

     function testShiftLUSDFromCurveToSPRevertsWhenZeroBLUSDSupply() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        bondNFT.totalSupply();

        // Shift bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_SHIFT);

        uint256 lusdToShift = 10e18;

        // Attempt to shift LUSD from Curve->SP There's none in Curve anyway, but it should revert with this reason string
        vm.expectRevert("CBM: bLUSD Supply must be > 0 upon shifting");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

     function testShiftLUSDFromCurveToSPRevertsBeforeEndOfShiftBootstrapPeriod() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // CI bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);
       
        // A chickens in
        chickenInForUser(A, A_bondID);

        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        assertGt(lusdToShift, 0);

        // Attempt to shift LUSD
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
        
        // Warp to the time that is half way through the shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT / 2); 
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Fastforward to 1 second before the shifter boostrap period ends
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT - 1); 
        vm.expectRevert("CBM: Shifter only callable after shift bootstrap period ends");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftCurveToSPSucceedsAfterEndOfShiftBootstrapPeriod() public{
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // CI bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);
       
        // A chickens in
        chickenInForUser(A, A_bondID);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        uint256 lusdInCurve_1 = chickenBondManager.getOwnedLUSDInCurve();
        assertGt(lusdInCurve_1, 0);
        
        vm.warp(block.timestamp + 1);
        _startShiftCountdownAndWarpInsideWindow();

        chickenBondManager.shiftLUSDFromCurveToSP(lusdInCurve_1 / 10);
        uint256 lusdInCurve_2 = chickenBondManager.getOwnedLUSDInCurve();
        assertLt(lusdInCurve_2, lusdInCurve_1);

        // Warp to some time after the end of bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT + 17 days);

        _startShiftCountdownAndWarpInsideWindow();

        // Check second shift Curve->SP succeeds
        chickenBondManager.shiftLUSDFromCurveToSP(lusdInCurve_1 / 10);
        uint256 lusdInCurve_3 = chickenBondManager.getOwnedLUSDInCurve();
        assertLt(lusdInCurve_3, lusdInCurve_2);
    }

    function testShiftLUSDFromCurveToSPRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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
        vm.expectRevert("CBM: 3CRV:LUSD exchange rate must be above the withdrawal threshold before Curve->SP shift");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftLUSDFromCurveToSPRevertsWhenShiftWouldRaiseCurvePriceAbove1() public {
        // A creates bond
        uint256 bondAmount = 700_000_000e18; // 700m

        deal(address(lusdToken), A, bondAmount);
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(50_000_000e18);
        emit log_named_decimal_uint("3CRV:LUSD exchange rate 0", _get3CRVLUSDExchangeRate(), 18);

        // Put some initial LUSD in SP (20% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(20);

        emit log_named_decimal_uint("3CRV:LUSD exchange rate 1", _get3CRVLUSDExchangeRate(), 18);
        makeCurveSpotPriceBelow1(50_000_000e18);
        emit log_named_decimal_uint("3CRV:LUSD exchange rate 2", _get3CRVLUSDExchangeRate(), 18);

        // Now, attempt to shift an amount which would raise the price back above 1.0, and expect it to fail
        vm.expectRevert("CBM: Curve->SP shift must increase 3CRV:LUSD exchange rate to a value above the withdrawal threshold");
        chickenBondManager.shiftLUSDFromCurveToSP(50_000_000e18);
        emit log_named_decimal_uint("3CRV:LUSD exchange rate 3", _get3CRVLUSDExchangeRate(), 18);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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

    function testShiftLUSDFromCurveToSPSlightlyIncreasesAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 100e18;
        uint256 A_bondID = createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDBefore, 0);

        uint256 exchangeRateBefore = curvePool.get_dy(1, 0, 1e36 / curveBasePool.get_virtual_price());
        uint256 lpSharesBefore = curvePool.totalSupply();
        uint256 virtualPriceBefore = curvePool.get_virtual_price();

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        uint256 exchangeRateAfter = curvePool.get_dy(1, 0, 1e36 / curveBasePool.get_virtual_price());
        uint256 lpSharesAfter = curvePool.totalSupply();

        assertGt(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
        assertLt(lpSharesAfter, lpSharesBefore);

        uint256 valueOfLPSharesBurnt = (lpSharesBefore - lpSharesAfter) * virtualPriceBefore / 1e18;
        uint256 shiftROI = (totalAcquiredLUSDAfter - totalAcquiredLUSDBefore) * 1e18 / valueOfLPSharesBurnt;

        emit log_named_decimal_uint("value of LP shares burnt", valueOfLPSharesBurnt, 18);
        emit log_named_decimal_uint("exchange rate before", exchangeRateBefore, 18);
        emit log_named_decimal_uint("exchange rate after", exchangeRateAfter, 18);
        emit log_named_decimal_uint("shift ROI (%)", shiftROI, 16);

        // The profit of withdrawing LUSD single-sidedly comes from swapping the 3CRV side of the
        // deposit to LUSD at a premium.
        // We made to pool LUSD-heavy to enable Curve => SP shifting, so less than half of the deposit
        // was held in 3CRV. (The exact proportion depends on the price and A factor).
        // Therefore in general, the ROI will be less than half of the premium.
        assertLt(exchangeRateAfter, exchangeRateBefore);
        assertLt(shiftROI, (exchangeRateBefore - 1e18) / 2);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalPermanentLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total permanent LUSD > 0
        uint256 totalPermanentLUSD = chickenBondManager.getPermanentLUSD();
        assertGt(totalPermanentLUSD, 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // get CBM's recorded total permanent LUSD before
        uint256 totalPermanentLUSDBefore = chickenBondManager.getPermanentLUSD();
        assertGt(totalPermanentLUSDBefore, 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalPermanentLUSDAfter = chickenBondManager.getPermanentLUSD();
        assertEq(totalPermanentLUSDAfter, totalPermanentLUSDBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMPendingLUSDTracker() public {// A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.getPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check pending LUSD After has not changed
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    function testPendingIsNotAffectedByShiftFromSPToCurve() public {
        // A, B, C create bond
        uint256 bondAmount = 100e18;

        uint256 A_bondID = createBondForUser(A, bondAmount);
        uint256 B_bondID = createBondForUser(B, bondAmount);
        uint256 C_bondID = createBondForUser(C, bondAmount);

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield, C);

        (uint256 lusdInSPAfter,,) = bammSPVault.getLUSDValue();

        // 1 month passes
        vm.warp(block.timestamp + 30 days);

        // C chickens in
        vm.startPrank(C);
        chickenBondManager.chickenIn(C_bondID);
        vm.stopPrank();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        // Shift all LUSD in SP
        makeCurveSpotPriceAbove1(200_000_000e18);
        uint256 lusdToShift = lusdInSPAfter - 1;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // A chickens out
        vm.startPrank(A);
        uint256 userABalanceBefore = lusdToken.balanceOf(A);
        chickenBondManager.chickenOut(A_bondID, 0);
        uint256 userABalanceAfter = lusdToken.balanceOf(A);
        vm.stopPrank();

        uint256 totalPendingLUSDAfterA = chickenBondManager.getPendingLUSD();

        // B chickens out
        vm.startPrank(B);
        uint256 userBBalanceBefore = lusdToken.balanceOf(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        uint256 userBBalanceAfter = lusdToken.balanceOf(B);
        vm.stopPrank();

        uint256 totalPendingLUSDAfterB = chickenBondManager.getPendingLUSD();

        // checks
        assertApproximatelyEqual(userABalanceAfter - userABalanceBefore, bondAmount, 100, "User A balance mismatch");
        assertApproximatelyEqual(userBBalanceAfter - userBBalanceBefore, bondAmount, 100, "User B balance mismatch");
        assertEq(totalPendingLUSDAfterA, bondAmount, "Pending after A chiken-out mismatch");
        assertEq(totalPendingLUSDAfterB, 0, "Pending after B chiken-out mismatch");
    }

    function testShiftFromSPToCurveIsImpossibleWithOnlyPending() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        createBondForUser(B, bondAmount);

        (uint256 lusdInSP,,) = bammSPVault.getLUSDValue();

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        // Shift all LUSD in SP
        makeCurveSpotPriceAbove1(200_000_000e18);
        uint256 lusdToShift = lusdInSP - 1;
        vm.expectRevert("CBM: bLUSD Supply must be > 0 upon shifting");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    // CBM Yearn and Curve trackers

    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInSPTracker() public {
        uint256 bondAmount = MIN_BOND_AMOUNT;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0, "total ac. lusd not < 0 after chicken in");


        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

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

        assertGt(acquiredLUSDInSPAfter, acquiredLUSDInSPBefore, "ac. LUSD after shift should have increased");
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInSPTracker() public {
        uint256 bondAmount = MIN_BOND_AMOUNT;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        // Get LUSD in Yearn Before
        (uint256 lusdInSPBefore,,) = bammSPVault.getLUSDValue();

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check LUSD in Yearn Increases
        (uint256 lusdInSPAfter,,) = bammSPVault.getLUSDValue();
        assertTrue(lusdInSPAfter > lusdInSPBefore);
    }

    function testShiftLUSDFromCurveToSPDecreasesCBMLUSDInCurveTracker() public {
        uint256 bondAmount = MIN_BOND_AMOUNT;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

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

    function testShiftLUSDFromCurveToSPGetsClamped() public {
        uint256 bondAmount = MIN_BOND_AMOUNT;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0, "total ac. lusd not < 0 after chicken in");

        // Get acquired LUSD in Yearn Before
        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();
        assertGt(acquiredLUSDInSPBefore, 0);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT); 

        _startShiftCountdownAndWarpInsideWindow();

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);

        assertGt(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        assertGt(chickenBondManager.getAcquiredLUSDInSP(), 0);

        // Shift LUSD from Curve to SP, try shift more than available
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() + 1;

        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check acquired LUSD in Yearn Increases
        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();

        assertGe(acquiredLUSDInSPAfter, acquiredLUSDInSPBefore, "ac. LUSD should be at least the same as the initial");
        assertLt(chickenBondManager.getOwnedLUSDInCurve(), 1e14, "All LUSD should have been moved from Curve");
    }

    // --- Curve withdrawal loss tests ---

    function testCurveImmediateLUSDDepositAndWithdrawalLossIsBounded(uint256 _depositAmount) public {
        // // Set Curve spot price to >1.0
        makeCurveSpotPriceAbove1(75_000_000e18);

        vm.assume(_depositAmount < 1e27 && _depositAmount > 1e18); // deposit in range [1, 1bil] LUSD

        // uint256 _depositAmount = 10e18;

        // Tip CBM some LUSD
        deal(address(lusdToken), address(chickenBondManager), _depositAmount);

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
        deal(address(_3crvToken), address(chickenBondManager), _depositAmount);

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

    function testCurveImmediateProportionalDepositAndWithdrawalIsLossless(uint256 _depositMagnitude) public {
        // _depositMagnitude is the fraction of the pool's current coin balances we'll deposit.
        // Make it a number between 1% and 1000%
        _depositMagnitude = coerce(_depositMagnitude, 1e16, 1e19);

        // Choose deposit amounts in proportion to the current coin balances, in order to keep the ratio constant
        uint256 _lusdDepositAmount = curvePool.balances(0) * _depositMagnitude / 1e18;
        uint256 _3crvDepositAmount = curvePool.balances(1) * _depositMagnitude / 1e18;

        // Tip CBM some LUSD and 3CRV
        deal(address(lusdToken), address(chickenBondManager), _lusdDepositAmount);
        deal(address(_3crvToken), address(chickenBondManager), _3crvDepositAmount);

        // Artificially deposit LUSD to Curve, as CBM
        vm.startPrank(address(chickenBondManager));

        lusdToken.approve(address(curvePool), _lusdDepositAmount);
        _3crvToken.approve(address(curvePool), _3crvDepositAmount);
        uint256 cbmShares = curvePool.add_liquidity([_lusdDepositAmount, _3crvDepositAmount], 0); // deposit both tokens

        uint256 cbmLUSDBalBefore = lusdToken.balanceOf(address(chickenBondManager));
        uint256 cbm3CRVBalBefore = _3crvToken.balanceOf(address(chickenBondManager));
        assertEq(cbmLUSDBalBefore, 0);
        assertEq(cbm3CRVBalBefore, 0);

        // Artificially withdraw all the share value as CBM
        curvePool.remove_liquidity(cbmShares, [uint256(0), uint256(0)]); // receive both LUSD and 3CRV, no minimums

        uint256 cbmLUSDBalAfter = lusdToken.balanceOf(address(chickenBondManager));
        uint256 cbm3CRVBalAfter = _3crvToken.balanceOf(address(chickenBondManager));

        // Check that we get back what we deposited
        assertApproximatelyEqual(cbmLUSDBalAfter, _lusdDepositAmount, 10);
        assertApproximatelyEqual(cbm3CRVBalAfter, _3crvDepositAmount, 10);
    }

    function loopOverCurveLUSDDepositSizes(int steps) public {
        uint256 depositAmount = 1e18;
        uint256 stepMultiplier = 10;

        // Loop over deposit sizes
        int step;
        while (step < steps) {
            // Tip CBM some LUSD
            deal(address(lusdToken), address(chickenBondManager), depositAmount);

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

    // --- Fee share test ---

    function testSendFeeShareCallableOnlyByYearnGov() public {
        // Create some bonds
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        deal(address(lusdToken), yearnGovernanceAddress, 37e18);
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
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        uint256 feeShare = 37e18;

        deal(address(lusdToken), yearnGovernanceAddress, feeShare);

        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        lusdToken.approve(address(chickenBondManager), feeShare);

        vm.expectRevert("CBM: Receive fee share only in normal mode");
        chickenBondManager.sendFeeShare(feeShare);
    }

    function testSendFeeShareInNormalModeIncreasesAcquiredLUSDInSP() public {
        // Create some bonds
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        uint256 feeShare = 37e18;

        deal(address(lusdToken), yearnGovernanceAddress, feeShare);
        vm.startPrank(yearnGovernanceAddress);
        lusdToken.approve(address(chickenBondManager), feeShare);
        vm.stopPrank();

        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();
        uint256 permanentLUSDBefore = chickenBondManager.getPermanentLUSD();
        uint256 pendingLUSDInSPBefore = chickenBondManager.getPendingLUSD();
        uint256 ownedLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        // Succeeds for Yearn governance
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.sendFeeShare(feeShare);

        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();
        uint256 permanentLUSDAfter = chickenBondManager.getPermanentLUSD();
        uint256 pendingLUSDInSPAfter = chickenBondManager.getPendingLUSD();
        uint256 ownedLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();

        //Check acquired LUSD In SP increased by correct amount
        uint256 tolerance = feeShare / 1e9;  // relative error tolerance of 1e-9
        assertApproximatelyEqual(acquiredLUSDInSPAfter - acquiredLUSDInSPBefore, feeShare, tolerance);

        // Other buckets don't change
        assertEq(permanentLUSDAfter, permanentLUSDBefore);
        assertEq(pendingLUSDInSPAfter, pendingLUSDInSPBefore);
        assertEq(ownedLUSDInCurveAfter, ownedLUSDInCurveBefore);
    }

    function testRedeemSandwichIncreaseLUSDPrice() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_SHIFT());

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        bLUSDToken.transfer(B, A_bLUSDBalance);
        assertEq(A_bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

       _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        chickenBondManager.shiftLUSDFromSPToCurve(chickenBondManager.getOwnedLUSDInSP());
        console.log("");
        console.log("After shift 1st time");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        uint256 B_curveBalance0 = curvePool.balanceOf(B);
        uint256 curveAcquiredBucket2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 redemptionPrice2 = chickenBondManager.calcSystemBackingRatio();

        // B redeems bLUSD
        vm.startPrank(B);
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, 0);
        // console.log(yearnCurveVault.balanceOf(B), "yearnCurveVault.balanceOf(B)");
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(B));
        vm.stopPrank();
        uint256 B_curveBalance1 = curvePool.balanceOf(B);
        // console.log("");
        // console.log("After redeem 1");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        // --- Reset state! ---
        setUp();

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_SHIFT());

        A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        // console.log("A chicken in");
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        bLUSDToken.transfer(B, A_bLUSDBalance);
        assertEq(A_bLUSDBalance, bLUSDToken.balanceOf(B), "A should transfer all bLUSD");
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        chickenBondManager.shiftLUSDFromSPToCurve(chickenBondManager.getOwnedLUSDInSP());
        console.log("");
        console.log("After shift 2nd time");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");

        console.log("");
        console.log("Manipulate pool");
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice before pool manipulation");
        uint256 initialCurvePrice = curvePool.get_dy_underlying(0, 1, 1e18);
        uint256 _3crvAmount = 2e24; // 2M
        deal(address(_3crvToken), C, _3crvAmount);
        uint256 C_3crvBalanceBefore = _3crvToken.balanceOf(C);
        uint256 C_lusdBalanceBefore = lusdToken.balanceOf(C);
        assertGe(C_3crvBalanceBefore, _3crvAmount);
        vm.startPrank(C);
        _3crvToken.approve(address(curvePool), _3crvAmount);
        curvePool.exchange(1, 0, _3crvAmount, 0, C);
        uint256 C_lusdBalanceAfter = lusdToken.balanceOf(C);
        vm.stopPrank();
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice after pool manipulation");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        uint256 curveAcquiredBucket3 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 redemptionPrice3 = chickenBondManager.calcSystemBackingRatio();

        // B redeems bLUSD
        vm.startPrank(B);
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, 0);
        // console.log(yearnCurveVault.balanceOf(B), "yearnCurveVault.balanceOf(B)");
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(B));
        vm.stopPrank();
        uint256 B_curveBalance2 = curvePool.balanceOf(B);
        //uint256 B_yearnBalance2 = yearnCurveVault.balanceOf(B);
        // console.log("");
        // console.log("After redeem 2");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        // Undo pool manipulation (finish sandwich attack)
        vm.startPrank(C);
        uint256 lusdAmount = C_lusdBalanceAfter - C_lusdBalanceBefore;
        lusdToken.approve(address(curvePool), lusdAmount);
        curvePool.exchange(0, 1, lusdAmount, 0, C);
        vm.stopPrank();
        uint256 finalCurvePrice = curvePool.get_dy_underlying(0, 1, 1e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice after pool manipulation undo");
        uint256 C_3crvBalanceFinal = _3crvToken.balanceOf(C);

        // Checks
        console.log("");
        // console.log(B_curveBalance0, "Curve B_balance0");
        // console.log(B_curveBalance1, "Curve B_balance1");
        // console.log(B_curveBalance2, "Curve B_balance2");
        console.log(B_curveBalance1 - B_curveBalance0, "Curve B_balance1 diff");
        console.log(B_curveBalance2 - B_curveBalance1, "Curve B_balance2 diff");
        console.log(C_lusdBalanceBefore, "Attacker LUSD Balance Before");
        console.log(lusdToken.balanceOf(C), "Attacker LUSD Balance After");
        console.log(C_3crvBalanceBefore, "Attacker 3crv Balance Before");
        console.log(C_3crvBalanceFinal, "Attacker 3crv Balance After");
        assertRelativeError(
            initialCurvePrice,
            finalCurvePrice,
            8e12, // 0.0008%
            "Price after attack should be close"
        );
        assertRelativeError(
            B_curveBalance1 - B_curveBalance0,
            B_curveBalance2 - B_curveBalance1,
            6e13, // 0.006%
            "Obtained Curve should be approximately equal"
        );
        // see: https://github.com/liquity/ChickenBond/pull/115#issuecomment-1184382984
        //console.log(curveAcquiredBucket2, "curveAcquiredBucket2");
        //console.log(curveAcquiredBucket3, "curveAcquiredBucket3");
        //console.log(redemptionPrice2, "redemptionPrice2");
        //console.log(redemptionPrice3, "redemptionPrice3");
        //console.log(curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2, "curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2");
        //console.log(redemptionPrice3 * 1e18 / redemptionPrice2, "redemptionPrice3 * 1e18 / redemptionPrice2");
        assertRelativeError(
            curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2,
            redemptionPrice3 * 1e18 / redemptionPrice2,
            2e13, // 0.002%
            "Redemption price and acquired bucket should grow the same (thx to manipulation fees)"
        );
        assertLe(
            (B_curveBalance2 - B_curveBalance1) * 1e18 / (B_curveBalance1 - B_curveBalance0),
            redemptionPrice3 * 1e18 / redemptionPrice2,
            "Increase in Curve balance should be less or equal than increase in redemption price"
        );
        assertRelativeError(
            C_3crvBalanceBefore,
            C_3crvBalanceFinal,
            1e15, // 0.1%
            "Attacker should have the same amount of 3CRV"
        );
    }

    function testRedeemSandwichDecreaseLUSDPrice() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_SHIFT());

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        bLUSDToken.transfer(B, A_bLUSDBalance);
        assertEq(A_bLUSDBalance, bLUSDToken.balanceOf(B), "A should transfer all bLUSD");
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        chickenBondManager.shiftLUSDFromSPToCurve(chickenBondManager.getOwnedLUSDInSP());
        console.log("");
        console.log("After shift 1st time");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        uint256 B_curveBalance0 = curvePool.balanceOf(B);

        // B redeems bLUSD
        vm.startPrank(B);
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, 0);
        // console.log(yearnCurveVault.balanceOf(B), "yearnCurveVault.balanceOf(B)");
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(B));
        vm.stopPrank();
        uint256 B_curveBalance1 = curvePool.balanceOf(B);
        // console.log("");
        // console.log("After redeem 1");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        // --- Reset state! ---
        setUp();

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_SHIFT());

        A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        // console.log("A chicken in");
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        bLUSDToken.transfer(B, A_bLUSDBalance);
        assertEq(A_bLUSDBalance, bLUSDToken.balanceOf(B), "A should transfer all bLUSD");
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        chickenBondManager.shiftLUSDFromSPToCurve(chickenBondManager.getOwnedLUSDInSP());
        console.log("");
        console.log("After shift 2nd time");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        uint256 curveAcquiredBucket2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 redemptionPrice2 = chickenBondManager.calcSystemBackingRatio();

        console.log("");
        console.log("Manipulate pool");
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice before pool manipulation");
        uint256 initialCurvePrice = curvePool.get_dy_underlying(0, 1, 1e18);
        uint256 lusdAmount = 30e24; // 30M
        deal(address(lusdToken), C, lusdAmount);
        uint256 C_lusdBalanceBefore = lusdToken.balanceOf(C);
        uint256 C_3crvBalanceBefore = _3crvToken.balanceOf(C);
        vm.startPrank(C);
        lusdToken.approve(address(curvePool), lusdAmount);
        curvePool.exchange(0, 1, lusdAmount, 0, C);
        vm.stopPrank();
        uint256 C_3crvBalanceAfter = _3crvToken.balanceOf(C);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice after pool manipulation");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        uint256 curveAcquiredBucket3 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 redemptionPrice3 = chickenBondManager.calcSystemBackingRatio();

        // B redeems bLUSD
        vm.startPrank(B);
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, 0);
        // console.log(yearnCurveVault.balanceOf(B), "yearnCurveVault.balanceOf(B)");
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(B));
        vm.stopPrank();
        uint256 B_curveBalance2 = curvePool.balanceOf(B);
        //uint256 B_yearnBalance2 = yearnCurveVault.balanceOf(B);
        // console.log("");
        // console.log("After redeem 2");
        // console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice");
        // console.log(chickenBondManager.getAcquiredLUSDInCurve(), "chickenBondManager.getAcquiredLUSDInCurve();");
        // console.log(yearnCurveVault.balanceOf(address(chickenBondManager)), "yearnCurveVault.balanceOf(address(chickenBondMananger))");
        // console.log(curvePool.totalSupply(), "curvePool.totalSupply()");

        // Undo pool manipulation (finish sandwich attack)
        uint256 _3crvAmount = C_3crvBalanceAfter - C_3crvBalanceBefore;
        assertGe(_3crvToken.balanceOf(C), _3crvAmount);
        vm.startPrank(C);
        _3crvToken.approve(address(curvePool), _3crvAmount);
        curvePool.exchange(1, 0, _3crvAmount, 0, C);
        vm.stopPrank();
        uint256 finalCurvePrice = curvePool.get_dy_underlying(0, 1, 1e18);
        console.log(curvePool.get_dy_underlying(0, 1, 1e18), "curveLUSDSpotPrice after pool manipulation undo");
        uint256 C_lusdBalanceFinal = lusdToken.balanceOf(C);

        // Checks
        console.log("");
        // console.log(B_curveBalance0, "Curve B_balance0");
        // console.log(B_curveBalance1, "Curve B_balance1");
        // console.log(B_curveBalance2, "Curve B_balance2");
        console.log(B_curveBalance1 - B_curveBalance0, "Curve B_balance1 diff");
        console.log(B_curveBalance2 - B_curveBalance1, "Curve B_balance2 diff");
        console.log(C_lusdBalanceBefore, "Attacker LUSD Balance Before");
        console.log(C_lusdBalanceFinal, "Attacker LUSD Balance After");
        console.log(C_3crvBalanceBefore, "Attacker 3crv Balance Before");
        console.log(_3crvToken.balanceOf(C), "Attacker 3crv Balance After");
        assertRelativeError(
            initialCurvePrice,
            finalCurvePrice,
            3e14, // 0.03%
            "Price after attack should be close"
        );
        assertRelativeError(
            B_curveBalance1 - B_curveBalance0,
            B_curveBalance2 - B_curveBalance1,
            9e14, // 0.09%
            "Obtained Curve should be approximately equal"
        );
        // see: https://github.com/liquity/ChickenBond/pull/115#issuecomment-1184382984
        //console.log(curveAcquiredBucket2, "curveAcquiredBucket2");
        //console.log(curveAcquiredBucket3, "curveAcquiredBucket3");
        //console.log(redemptionPrice2, "redemptionPrice2");
        //console.log(redemptionPrice3, "redemptionPrice3");
        //console.log(curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2, "curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2");
        //console.log(redemptionPrice3 * 1e18 / redemptionPrice2, "redemptionPrice3 * 1e18 / redemptionPrice2");
        assertRelativeError(
            curveAcquiredBucket3 * 1e18 / curveAcquiredBucket2,
            redemptionPrice3 * 1e18 / redemptionPrice2,
            2e13, // 0.002%
            "Redemption price and acquired bucket should grow the same (thx to manipulation fees)"
        );
        assertLe(
            (B_curveBalance2 - B_curveBalance1) * 1e18 / (B_curveBalance1 - B_curveBalance0),
            redemptionPrice3 * 1e18 / redemptionPrice2,
            "Increase in Curve balance should be less or equal than increase in redemption price"
        );
        assertRelativeError(
            C_lusdBalanceBefore,
            C_lusdBalanceFinal,
            1e15, // 0.1%
            "Attacker should have the same amount of LUSD"
        );
    }

    // Curve bLUSD:LUSD pool tests

    function testBLUSDPoolBreaksAfterTotalWithdrawal() public {
        uint256 amount = 1000e18;
        uint256 bondID = createBondForUser(A, amount);
        vm.warp(block.timestamp + 100 days);
        chickenInForUser(A, bondID);

        deal(address(lusdToken), A, amount);
        
        vm.startPrank(A); {
            lusdToken.approve(address(bLUSDCurvePool), type(uint256).max);
            bLUSDToken.approve(address(bLUSDCurvePool), type(uint256).max);

            uint256 lp = bLUSDCurvePool.add_liquidity([bLUSDToken.balanceOf(A), lusdToken.balanceOf(A)], 0);
            console.log(lp, "LP");
            console.log(ERC20(bLUSDCurvePool.token()).totalSupply(), "Curve pool total supply");
            bLUSDCurvePool.remove_liquidity(lp, [uint256(0), uint256(0)]);

            lusdToken.transfer(B, lusdToken.balanceOf(A));
            bLUSDToken.transfer(B, bLUSDToken.balanceOf(A));
        } vm.stopPrank();

        // Now B can't deposit any more, yikes
        vm.startPrank(B); {
            lusdToken.approve(address(bLUSDCurvePool), type(uint256).max);
            bLUSDToken.approve(address(bLUSDCurvePool), type(uint256).max);

            // Can't inline this into add_liquidity(), because it trips up vm.expectRevert()
            uint256[2] memory amounts = [bLUSDToken.balanceOf(B), lusdToken.balanceOf(B)];

            console.log(bLUSDCurvePool.D(), "D");
            console.log(bLUSDCurvePool.future_A_gamma_time(), "future A gamma time");
            // the problem is that the pool isn’t actually emptied, because Curve pool code subtracts 1
            // for rounding issues. Therefore old D is not zero (as can be seen in the log above).
            vm.expectRevert();
            bLUSDCurvePool.add_liquidity(amounts, 0);
        } vm.stopPrank();
    }
}
