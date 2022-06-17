pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";


contract LQTYChickenBondManagerMainnetOnlyTest is BaseTest, MainnetTestSetup {
    function _pickleHarvestAndFastForward() internal returns (uint256) {
        // harvest
        uint256 prevValue = chickenBondManager.calcTotalPickleJarShareValue();
        //address controller = pickleJar.controller();
        //vm.startPrank(controller);
        //pickleJar.harvest();

        // some time passes to unlock profits
        vm.warp(block.timestamp + 600);
        vm.stopPrank();
        uint256 valueIncrease = chickenBondManager.calcTotalPickleJarShareValue() - prevValue;
        return valueIncrease;
    }

    // --- chickening in when sTOKEN supply is zero ---

    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Pickle LQTY Vault gets some yield
        uint256 initialYield = _pickleHarvestAndFastForward();

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLQTY_A = chickenBondManager.calcAccruedBLQTY(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lqtyToken.balanceOf(address(curveLiquidityGauge)), initialYield + chickenInFeeAmount, 7, "Balance of rewards contract doesn't match");

        // check bLQTY A balance
        assertEq(bLQTYToken.balanceOf(A), accruedBLQTY_A, "bLQTY balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLQTY_A = chickenBondManager.calcAccruedBLQTY(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(
            lqtyToken.balanceOf(address(curveLiquidityGauge)),
            chickenInFeeAmount,
            10,
            "Balance of rewards contract doesn't match"
        );

        // check bLQTY A balance
        assertEq(bLQTYToken.balanceOf(A), accruedBLQTY_A, "bLQTY balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionAndPickleHarvestTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 600);

        // Pickle LQTY Vault gets some yield
        uint256 initialYield = _pickleHarvestAndFastForward();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        assertApproximatelyEqual(
            lqtyToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + chickenInFeeAmount,
            12,
            "Balance of rewards contract after A's chicken-in doesn't match"
        );

        vm.warp(block.timestamp + 600);

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(bLQTYToken.balanceOf(A));
        vm.stopPrank();

        // Confirm total bLQTY supply is 0
        assertEq(bLQTYToken.totalSupply(), 0, "bLQTY supply not 0 after full redemption");

        // Pickle LQTY Vault gets some yield
        uint256 secondYield = _pickleHarvestAndFastForward();

        // B chickens in
        vm.startPrank(B);
        uint256 accruedBLQTY_B = chickenBondManager.calcAccruedBLQTY(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        uint256 yieldFromFirstChickenInRedemptionFee = bLQTYBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertApproximatelyEqual(
            lqtyToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + secondYield + 2 * chickenInFeeAmount + yieldFromFirstChickenInRedemptionFee,
            20,
            "Balance of rewards contract after B's chicken-in doesn't match"
        );

        // check CBM holds no LQTY
        assertEq(lqtyToken.balanceOf(address(chickenBondManager)), 0, "cbm holds non-zero lqty");

        // check bLQTY B balance
        assertEq(bLQTYToken.balanceOf(B), accruedBLQTY_B, "bLQTY balance of B doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionAndBancorHarvestTransfersToRewardsContract() external {
        uint256 bondAmount1 = 1000e18;
        uint256 bondAmount2 = 100e18;
        deal(address(lqtyToken), A, bondAmount1 + bondAmount2);

        // create bond
        uint256 A_bondID = createBondForUser(A, bondAmount1);

        // wait 100 days
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(bLQTYToken.balanceOf(A));
        vm.stopPrank();

        // harvest bancor and fast forward time to unlock profits
        uint256 bancorYield = _generateBancorRevenue(1e22, 2);
        assertGt(bancorYield, 0, "Yield generated in Bancor vault should be greater than zero");

        // create bond
        A_bondID = createBondForUser(A, bondAmount2);

        // wait 100 days more
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        uint256 accruedBLQTY = chickenBondManager.calcAccruedBLQTY(A_bondID);

        uint256 previousPermanentLQTY = chickenBondManager.getPermanentLQTY();

        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // checks
        assertRelativeError(
            chickenBondManager.calcSystemBackingRatio(),
            1e18,
            8e14, // 0.08%
            "Backing ratio should be 1"
        );

        // Acquired
        assertApproximatelyEqual(
            chickenBondManager.getAcquiredLQTY(),
            accruedBLQTY, // backing ratio is 1, so this will match
            10,
            "Acquired LQTY mismatch"
        );

        // Balance in rewards contract
        // uint256 yieldFromFirstChickenInRedemptionFee = bLQTYBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertRelativeError(
            lqtyToken.balanceOf(address(curveLiquidityGauge)),
            // chickenInFeeAmount1 + chickenInFeeAmount2 + yieldFromFirstChickenInRedemptionFee,
            _getChickenInFeeForAmount(bondAmount1) + _getChickenInFeeForAmount(bondAmount2) + bLQTYBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18,
            4e10, // 0.000004 %
            "Rewards contract balance mismatch"
        );

        // Bancor yield becomes permanent (to avoid the hassle of the cooldown period)
        assertApproximatelyEqual(
            previousPermanentLQTY + bancorYield + (_getAmountMinusChickenInFee(bondAmount2) - accruedBLQTY), // backing ratio is 1
            chickenBondManager.getPermanentLQTY() ,
            10,
            "Permanent LQTY mismatch"
        );

        // Acquired in Bancor is therefore zero
        assertEq(chickenBondManager.getAcquiredLQTYInBancorPool(), 0, "Acquired in Bancor should be zero");
    }

    // --- redemption tests ---

    function testRedeemDecreasesAcquiredLQTYByCorrectFraction(uint256 redemptionFraction) public {
        // Fraction between 1 billion'th, and 100%.  If amount is too tiny, redemption can revert due to attempts to
        // withdraw 0 LQTYfrom Pickle (due to rounding in share calc).
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

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        vm.stopPrank();

        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        assertEq(bLQTYToken.totalSupply(), bLQTYToken.balanceOf(B));

        // Get acquired LQTY before
        uint256 acquiredLQTYBefore = chickenBondManager.getAcquiredLQTY();
        uint256 permanentLQTYBefore = chickenBondManager.getPermanentLQTY();
        assertGt(acquiredLQTYBefore, 0, "Acquired should be greater than zero");
        assertGt(permanentLQTYBefore, 0, "Permanent should be greater than zero");

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(bLQTYToRedeem, bLQTYToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(bLQTYToRedeem);
        vm.stopPrank();

        // Check acquired LQTY in curve after has reduced by correct fraction
        uint256 acquiredLQTYAfter = chickenBondManager.getAcquiredLQTY();
        uint256 expectedAcquiredLQTYAfter = acquiredLQTYBefore * expectedFractionRemainingAfterRedemption / 1e18;

        //console.log(acquiredLQTYBefore, "acquiredLQTYBefore");
        //console.log(acquiredLQTYAfter, "acquiredLQTYAfter");
        //console.log(expectedAcquiredLQTYAfter, "expectedAcquiredLQTYAfter");
        uint256 tolerance = acquiredLQTYBefore / 1000; // Assume 0.1% relative error tolerance
        assertApproximatelyEqual(acquiredLQTYAfter, expectedAcquiredLQTYAfter, tolerance, "Final acquired LQTY in Curve mismatch");
    }
}
