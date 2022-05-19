pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";
import "../Interfaces/StrategyAPI.sol";


contract ChickenBondManagerMainnetOnlyTest is BaseTest, MainnetTestSetup {
    function _harvest() internal returns (uint256) {
        // get strategy
        address strategy = yearnLUSDVault.withdrawalQueue(0);
        // get keeper
        address keeper = StrategyAPI(strategy).keeper();

        // harvest
        uint256 prevValue = chickenBondManager.calcTotalYearnLUSDVaultShareValue();
        vm.startPrank(keeper);
        StrategyAPI(strategy).harvest();

        // some time passes to unlock profits
        vm.warp(block.timestamp + 600);
        vm.stopPrank();
        uint256 valueIncrease = chickenBondManager.calcTotalYearnLUSDVaultShareValue() - prevValue;

        return valueIncrease;
    }

    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 taxAmount = _getTaxForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = _harvest();

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), initialYield + taxAmount, 6, "Balance of rewards contract doesn't match");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 taxAmount = _getTaxForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), taxAmount, 1, "Balance of rewards contract doesn't match");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 taxAmount = _getTaxForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = _harvest();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // A redeems full
        vm.startPrank(A);
        chickenBondManager.redeem(sLUSDToken.balanceOf(A));
        vm.stopPrank();

        // Yearn LUSD Vault gets some yield
        uint256 secondYield = _harvest();

        // B chickens in
        vm.startPrank(B);
        uint256 accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(sLUSDLPRewardsStaking)),
            initialYield + secondYield + 2 * taxAmount,
            11,
            "Balance of rewards contract doesn't match"
        );
        // check sLUSD B balance
        assertEq(sLUSDToken.balanceOf(B), accruedSLUSD_B, "sLUSD balance of B doesn't match");
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
        // TODO: Artificially raise Yearn LUSD vault deposit limit to accommodate sufficient LUSD for the test
        vm.startPrank(yearnGovernanceAddress);
        yearnLUSDVault.setDepositLimit(1e27);
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
        assertApproximatelyEqual(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 1e15);
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
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check acquired LUSD in Yearn has decreased
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter < acquiredLUSDInYearnBefore);
    }

    function testShiftLUSDFromSPToCurveDecreasesCBMLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get CBM's view of LUSD in Yearn  
        uint256 lusdInYearnBefore = chickenBondManager.calcTotalYearnLUSDVaultShareValue();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Yearn has decreased
        uint256 lusdInYearnAfter = chickenBondManager.calcTotalYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter < lusdInYearnBefore);
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
        uint256 B_bondID = bondNFT.totalMinted();
       
        // time passes
        vm.warp(block.timestamp + 30 days);
      
        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get the total LUSD in Yearn and Curve before
        uint256 cbmLUSDInYearnBefore = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Get actual SP and Curve pool LUSD Balances before
        uint256 yearnLUSDVaultBalanceBefore =  lusdToken.balanceOf(address(yearnLUSDVault));
        uint256 CurveBalanceBefore = lusdToken.balanceOf(address(curvePool));

        // Shift to Curve
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10; // Shift 10% of total owned LUSD
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get the total LUSD in Yearn and Curve after
        uint256 cbmLUSDInYearnAfter = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();

        // Get actual SP and Curve pool LUSD Balances after
        uint256 yearnLUSDVaultBalanceAfter = lusdToken.balanceOf(address(yearnLUSDVault));
        uint256 CurveBalanceAfter = lusdToken.balanceOf(address(curvePool));

        // Check Yearn LUSD vault decreases
        assertLt(cbmLUSDInYearnAfter, cbmLUSDInYearnBefore);
        assertLt(yearnLUSDVaultBalanceAfter, yearnLUSDVaultBalanceBefore);
        // Check Curve pool increases
        assertGt(cbmLUSDInCurveAfter, cbmLUSDInCurveBefore);
        assertGt(CurveBalanceAfter, CurveBalanceBefore);

        uint256 cbmyearnLUSDVaultDecrease = cbmLUSDInYearnBefore - cbmLUSDInYearnAfter; // Yearn LUSD vault decreases
        uint256 cbmCurveIncrease = cbmLUSDInCurveAfter - cbmLUSDInCurveBefore; // Curve increases
    
        uint256 yearnLUSDVaultBalanceDecrease = yearnLUSDVaultBalanceBefore - yearnLUSDVaultBalanceAfter;
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
        uint256 lossRelativeToYearnVault = diffOrZero(cbmyearnLUSDVaultDecrease, yearnLUSDVaultBalanceDecrease) * 1e18 / yearnLUSDVaultBalanceDecrease;
       
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
        uint256 B_bondID = bondNFT.totalMinted();
       
        // time passes
        vm.warp(block.timestamp + 30 days);
      
        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get permanent LUSD in both pools before
        uint256 permanentLUSDInCurve_1 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInYearn_1 = chickenBondManager.getPermanentLUSDInYearn();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;

        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 permanentLUSDInCurve_2 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInYearn_2 = chickenBondManager.getPermanentLUSDInYearn();
        
        // check SP permanent decrease approx == Curve permanent increase
        uint256 permanentLUSDYearnDecrease_1 = permanentLUSDInYearn_1 - permanentLUSDInYearn_2;
        uint256 permanentLUSDCurveIncrease_1 = permanentLUSDInCurve_2 - permanentLUSDInCurve_1;
      
        uint256 relativePermanentLoss = diffOrZero(permanentLUSDYearnDecrease_1, permanentLUSDCurveIncrease_1) * 1e18 / (permanentLUSDInYearn_1 + permanentLUSDInCurve_1);
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
        uint256 B_bondID = bondNFT.totalMinted();
       
        // time passes
        vm.warp(block.timestamp + 30 days);
      
        // A chickens in
        chickenInForUser(A, A_bondID);

        // Get permanent LUSD in both pools before
        uint256 acquiredLUSDInCurve_1 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInYearn_1 = chickenBondManager.getAcquiredLUSDInYearn();

        makeCurveSpotPriceAbove1(200_000_000e18);

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / 10;
       
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 acquiredLUSDInCurve_2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInYearn_2 = chickenBondManager.getAcquiredLUSDInYearn();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 acquiredLUSDYearnDecrease_1 = acquiredLUSDInYearn_1 - acquiredLUSDInYearn_2;
        uint256 acquiredLUSDCurveIncrease_1 = acquiredLUSDInCurve_2 - acquiredLUSDInCurve_1;
      
        uint256 relativeAcquiredLoss = diffOrZero(acquiredLUSDYearnDecrease_1, acquiredLUSDCurveIncrease_1) * 1e18 / acquiredLUSDInYearn_1 + acquiredLUSDInCurve_1;

        // Check that any discrepancy between the acquired SP decrease and the acquired Curve increase from shifting is <0.01% of 
        // the initial acquired LUSD in the SP
        assertLt(relativeAcquiredLoss, 1e14);
    }

    // Actual Yearn and Curve balance tests
    // function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInYearnAndCurve() public {}

    // function testShiftLUSDFromSPToCurveDecreasesLUSDInYearn() public {}
    // function testShiftLUSDFromSPToCurveIncreaseLUSDInCurve() public {}

    // function testFailShiftLUSDFromSPToCurveWhen0LUSDInYearn() public {}
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
    //     yearnLUSDVault.setDepositLimit(1e27);
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
        assertApproximatelyEqual(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 1e3);
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

    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInYearnTracker() public {
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

        makeCurveSpotPriceAbove1(200_000_000e18);
        // Put some initial LUSD in SP (10% of its acquired + permanent) into Curve
        shiftFractionFromSPToCurve(10);
        makeCurveSpotPriceBelow1(200_000_000e18);
      
        uint256 permanentYearnAfterShift = chickenBondManager.getPermanentLUSDInYearn();
        uint256 permanentCurveAfterShift = chickenBondManager.getPermanentLUSDInCurve();
        assertGt(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        assertGt(chickenBondManager.getAcquiredLUSDInYearn(), 0);

        // Get acquired LUSD in Yearn Before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();
        assertGt(acquiredLUSDInYearnBefore, 0);

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
      
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
       
        // Check acquired LUSD in Yearn Increases
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
       
        assertGt(acquiredLUSDInYearnAfter, acquiredLUSDInYearnBefore);
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInYearnTracker() public {
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
        uint256 lusdInYearnBefore = chickenBondManager.calcTotalYearnLUSDVaultShareValue();

        // Shift LUSD from Curve to SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check LUSD in Yearn Increases
        uint256 lusdInYearnAfter = chickenBondManager.calcTotalYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter > lusdInYearnBefore);
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
        uint256 B_bondID = bondNFT.totalMinted();
       
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
        uint256 cbmLUSDInYearnBefore = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveBefore = chickenBondManager.getOwnedLUSDInCurve();

        // Get actual SP and Curve pool LUSD Balances before
        uint256 yearnLUSDVaultBalanceBefore =  lusdToken.balanceOf(address(yearnLUSDVault));
        uint256 CurveBalanceBefore = lusdToken.balanceOf(address(curvePool));

        // Shift Curve->SP
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10; // Shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
       
        // Get the total LUSD in Yearn and Curve after
        uint256 cbmLUSDInYearnAfter = chickenBondManager.getOwnedLUSDInSP();
        uint256 cbmLUSDInCurveAfter = chickenBondManager.getOwnedLUSDInCurve();
       
        // Get actual SP and Curve pool LUSD Balances after
        uint256 yearnLUSDVaultBalanceAfter = lusdToken.balanceOf(address(yearnLUSDVault));
        uint256 CurveBalanceAfter = lusdToken.balanceOf(address(curvePool));

        // Check Yearn LUSD vault increases
        assertGt(cbmLUSDInYearnAfter, cbmLUSDInYearnBefore);
        assertGt(yearnLUSDVaultBalanceAfter, yearnLUSDVaultBalanceBefore);
        // Check Curve pool decreases
        assertLt(cbmLUSDInCurveAfter, cbmLUSDInCurveBefore);
        assertLt(CurveBalanceAfter, CurveBalanceBefore);
        
        uint256 cbmyearnLUSDVaultIncrease = cbmLUSDInYearnAfter - cbmLUSDInYearnBefore; // Yearn LUSD vault increases
        uint256 cbmCurveDecrease = cbmLUSDInCurveBefore - cbmLUSDInCurveAfter; // Curve decreases
    
        uint256 yearnLUSDVaultBalanceIncrease = yearnLUSDVaultBalanceAfter - yearnLUSDVaultBalanceBefore;
        uint256 CurveBalanceDecrease = CurveBalanceBefore - CurveBalanceAfter;

        /*Calculate the relative losses, if there are any.
        * Our relative Curve loss is positive if CBM has lost more than Curve has lost.
        * Our relative Yearn LUSD loss is positive if Yearn LUSD vault has gained more than CBM has gained.
        */
        uint256 lossRelativeToCurvePool = diffOrZero(cbmCurveDecrease, CurveBalanceDecrease) * 1e18 / CurveBalanceDecrease;    
        uint256 lossRelativeToYearnLUSDVault = diffOrZero(yearnLUSDVaultBalanceIncrease, cbmyearnLUSDVaultIncrease) * 1e18 / yearnLUSDVaultBalanceIncrease;
       
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
        uint256 B_bondID = bondNFT.totalMinted();
       
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
        uint256 permanentLUSDInYearn_1 = chickenBondManager.getPermanentLUSDInYearn();
        assertGt(permanentLUSDInCurve_1, 0);
        assertGt(permanentLUSDInYearn_1, 0);

        // Shift 10% of owned LUSD in Curve;
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10;
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 permanentLUSDInCurve_2 = chickenBondManager.getPermanentLUSDInCurve();
        uint256 permanentLUSDInYearn_2 = chickenBondManager.getPermanentLUSDInYearn();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 permanentLUSDYearnIncrease_1 = permanentLUSDInYearn_2 - permanentLUSDInYearn_1;
        uint256 permanentLUSDCurveDecrease_1 = permanentLUSDInCurve_1 - permanentLUSDInCurve_2;
      
        uint256 relativePermanentLoss = diffOrZero(permanentLUSDCurveDecrease_1, permanentLUSDYearnIncrease_1) * 1e18 / (permanentLUSDInCurve_1 + permanentLUSDInYearn_1);
       
       // Check that any relative loss in the permanent bucket from shifting Curve->SP is less than 1 million'th of total permanent LUSD
        assertLt(relativePermanentLoss, 1e12);
    }

    function testShiftLUSDFromCurveToSPChangesAcquiredBucketsBySimilarAmount(uint256 bondAmount) public {
        vm.assume(bondAmount < 1e24 && bondAmount > 1e18);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();
       
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
        uint256 acquiredLUSDInYearn_1 = chickenBondManager.getAcquiredLUSDInYearn();
        assertGt(acquiredLUSDInCurve_1, 0);
        assertGt(acquiredLUSDInYearn_1, 0);
        
        // Shift 10% of owned LUSD in Curve 
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInCurve() / 10;
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Get permanent LUSD in both pools after
        uint256 acquiredLUSDInCurve_2 = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredLUSDInYearn_2 = chickenBondManager.getAcquiredLUSDInYearn();

        // check SP permanent decrease approx == Curve permanent increase
        uint256 acquiredLUSDYearnIncrease_1 = acquiredLUSDInYearn_2 - acquiredLUSDInYearn_1;
        uint256 acquiredLUSDCurveDecrease_1 = acquiredLUSDInCurve_1 - acquiredLUSDInCurve_2;
      
       uint256 relativeAcquiredLoss = diffOrZero(acquiredLUSDCurveDecrease_1, acquiredLUSDYearnIncrease_1) * 1e18 / (acquiredLUSDInYearn_1 + acquiredLUSDInCurve_1);

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
        
        console.log(curveRelativeDepositLoss, "curveRelativeDepositLoss");
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
        uint256 cbm3CRVBalBeforeDep = _3crvToken.balanceOf(address(chickenBondManager));
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
        uint256 _depositMagnitude = 10e18;
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
}
