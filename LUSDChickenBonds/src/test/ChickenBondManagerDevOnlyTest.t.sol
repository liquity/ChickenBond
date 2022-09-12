pragma solidity ^0.8.10;

import "../ExternalContracts/MockYearnVault.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/DevTestSetup.sol";


contract ChickenBondManagerDevOnlyTest is BaseTest, DevTestSetup {
    function _generateBAMMYield(uint256 _yieldAmount) internal {
        deal(address(lusdToken), address(bammSPVault), lusdToken.balanceOf(address(bammSPVault)) + _yieldAmount);
        chickenBondManager.updateBAMMDebt();
    }

    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), initialYield + chickenInFeeAmount, 2, "Balance of rewards contract doesn't match");

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertEq(lusdToken.balanceOf(address(curveLiquidityGauge)), chickenInFeeAmount, "Balance of rewards contract doesn't match");

        // check bLUSD A balance
        assertEq(bLUSDToken.balanceOf(A), accruedBLUSD_A, "bLUSD balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionAlmostDepletionAndSPHarvestTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B.Protocol LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // A redeems can’t redeem full, redeems max possible
        vm.startPrank(A);
        // TODO
        //vm.expectRevert("CBM: Cannot redeem below min supply");
        //chickenBondManager.redeem(bLUSDToken.balanceOf(A), 0);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A) - MIN_BLUSD_SUPPLY, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // B.Protocol LUSD Vault gets some yield
        uint256 secondYield = 4e18;
        _generateBAMMYield(secondYield);

        // B chickens in
        vm.startPrank(B);
        uint256 accruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + 2 * chickenInFeeAmount,
            5,
            "Balance of rewards contract doesn't match"
        );
        // check bLUSD B balance
        assertEq(bLUSDToken.balanceOf(B), accruedBLUSD_B, "bLUSD balance of B doesn't match");
    }

    function testFirstChickenInAfterRedemptionAlmostDepletionAndCurveHarvestTransfersToRewardsContract() external {
        uint256 bondAmount1 = 1000e18;
        uint256 bondAmount2 = 100e18;

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
        MockCurvePool(address(curvePool)).setNextPrankPrice(105e16);
        shiftFractionFromSPToCurve(2);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 initialPermanentLUSD = chickenBondManager.getPermanentLUSD();

        // A redeems can’t redeem full, redeems max possible
        uint256 redeemAmount = bLUSDToken.balanceOf(A) - MIN_BLUSD_SUPPLY;
        uint256 redemptionFeeAmount = redeemAmount * chickenBondManager.calcRedemptionFeePercentage(redeemAmount * 1e18 / bLUSDToken.balanceOf(A)) / 1e18 * chickenBondManager.calcSystemBackingRatio() / 1e18;
        vm.startPrank(A);
        // TODO
        //vm.expectRevert("CBM: Cannot redeem below min supply");
        //vm.expectRevert(abi.encodePacked("CBM: Cannot redeem below min supply"));
        //chickenBondManager.redeem(bLUSDToken.balanceOf(A), 0);
        chickenBondManager.redeem(redeemAmount, 0);
        // A withdraws from Yearn to make math simpler, otherwise harvest would be shared
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(A));
        vm.stopPrank();
        uint256 acquiredLUSDAfterRedemption = chickenBondManager.getTotalAcquiredLUSD();

        // harvest curve
        uint256 prevValue = chickenBondManager.getTotalLUSDInCurve();
        MockYearnVault(address(yearnCurveVault)).harvest(1000e18);
        uint256 curveYield = chickenBondManager.getTotalLUSDInCurve() - prevValue;

        // create bond
        A_bondID = createBondForUser(A, bondAmount2);

        // wait 100 days more
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        uint256 lusdToAcquire2 = chickenBondManager.getLUSDToAcquire(A_bondID);

        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Checks

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
            1,
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
            250,
            "Rewards contract balance mismatch"
        );
    }

    function testFirstChickenInWithoutEnoughLUSDInBAMM() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield);

        uint256 acquiredLUSDInSP = chickenBondManager.getAcquiredLUSDInSP();
        // simulate B.Protocol loss
        uint256 bammLoss = lusdToken.balanceOf(address(bammSPVault)) - acquiredLUSDInSP + 1;
        vm.startPrank(address(bammSPVault));
        lusdToken.transfer(C, bammLoss);
        vm.stopPrank();

        // A chickens in
        vm.startPrank(A);
        vm.expectRevert("CBM: Not enough LUSD available in B.Protocol");
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // simulate B.Protocol recover loss
        vm.startPrank(C);
        lusdToken.transfer(address(bammSPVault), bammLoss);
        vm.stopPrank();

        // now it works
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();
    }

    function testFirstChickenInWithoutEnoughLUSDInBAMMForChickenInFee() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        _generateBAMMYield(initialYield);

        uint256 acquiredLUSDInSP = chickenBondManager.getAcquiredLUSDInSP();
        // simulate B.Protocol loss
        vm.startPrank(address(bammSPVault));
        lusdToken.transfer(C, lusdToken.balanceOf(address(bammSPVault)) - acquiredLUSDInSP);
        vm.stopPrank();

        // now it works
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // rewards contract has only initial acquired, but no fee
        assertEq(lusdToken.balanceOf(address(curveLiquidityGauge)), acquiredLUSDInSP, "Rewards contract balance mismatch");
    }

    function testChickenOutMinTooBig() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens out
        vm.startPrank(A);
        vm.expectRevert("CBM: Min value cannot be greater than nominal amount");
        chickenBondManager.chickenOut(A_bondID, bondAmount + 1);
        vm.stopPrank();
    }

    function testChickenOutBelowMin() public {
        // A creates bond
        uint256 bondAmount = MIN_BOND_AMOUNT;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // simulate B.Protocol loss
        vm.startPrank(address(bammSPVault));
        lusdToken.transfer(C, bondAmount / 2);
        vm.stopPrank();

        // A chickens out
        vm.startPrank(A);
        vm.expectRevert("CBM: Not enough LUSD available in B.Protocol");
        chickenBondManager.chickenOut(A_bondID, bondAmount / 2 + 1);
        // with the remaining amount it works
        chickenBondManager.chickenOut(A_bondID, bondAmount / 2);
        vm.stopPrank();
    }

    function testRedeemMinTooBig() public {
        // A creates bond
        uint256 bondAmount = 100e18;

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

        uint256 acquiredLUSD = chickenBondManager.getAcquiredLUSDInSP();
        // B redeems bLUSD
        vm.startPrank(B);
        vm.expectRevert("CBM: Min value cannot be greater than nominal amount");
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, acquiredLUSD + 1);
        vm.stopPrank();
    }

    function testRedeemBelowMin() public {
        // A creates bond
        uint256 bondAmount = 100e18;

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

        // simulate B.Protocol loss
        uint256 leftInBAMMSPVault = 10;
        //console.log(chickenBondManager.getAcquiredLUSDInSP(), "chickenBondManager.getAcquiredLUSDInSP()");
        //console.log(chickenBondManager.getPermanentLUSD(), "chickenBondManager.getPermanentLUSD()");
        vm.startPrank(address(bammSPVault));
        lusdToken.transfer(C, lusdToken.balanceOf(address(bammSPVault)) - leftInBAMMSPVault);
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // B redeems bLUSD
        vm.startPrank(B);
        vm.expectRevert("CBM: Not enough LUSD available in B.Protocol");
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, leftInBAMMSPVault + 1);
        // with the remaining amount it works
        chickenBondManager.redeem(A_bLUSDBalance - MIN_BLUSD_SUPPLY, leftInBAMMSPVault);
        vm.stopPrank();
    }

    function testLiquityExtraData() public {
        uint256 bondAmount = 100e18;
        uint256 bondID = createBondForUser(A, bondAmount);

        (
            uint80 bdInitialHalfDna,
            uint80 bdFinalHalfDna,
            uint256 bdTroveSize,
            uint256 bdLQTYAmount,
            uint256 bdCurveGaugeSlopes
        ) = bondNFT.getBondExtraData(bondID);
        uint80 initialHalfDna = bdInitialHalfDna;
        assertGt(bdInitialHalfDna, 0);
        assertEq(bdFinalHalfDna, 0);
        assertEq(bdTroveSize, 0);
        assertEq(bdLQTYAmount, 0);
        assertEq(bdCurveGaugeSlopes, 0);

        // set mock values
        uint256 mockTroveDebt = 1e18;
        uint256 mockLQTYAmount = 2e18;
        uint256 mockCurveGaugeSlopes = 3e15;
        MockTroveManager(address(bondNFT.troveManager())).setTroveDebt(mockTroveDebt);
        MockLQTYStaking(address(bondNFT.lqtyStaking())).setStake(mockLQTYAmount);
        MockCurveGaugeController(address(bondNFT.curveGaugeController())).setSlope(mockCurveGaugeSlopes);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        chickenInForUser(A, bondID);

        (bdInitialHalfDna, bdFinalHalfDna, bdTroveSize, bdLQTYAmount, bdCurveGaugeSlopes) = bondNFT.getBondExtraData(bondID);
        assertGt(bdInitialHalfDna, 0);
        assertGt(bdFinalHalfDna, 0);
        assertEq(bdInitialHalfDna, initialHalfDna);
        assert(bdFinalHalfDna != bdInitialHalfDna);
        assertEq(bdTroveSize, mockTroveDebt / 1e18);
        assertEq(bdLQTYAmount, mockLQTYAmount / 1e18);
        assertEq(bdCurveGaugeSlopes, 2 * mockCurveGaugeSlopes / 1e9); // It calls the controller twice, for 3CRV and FRAX
    }
}
