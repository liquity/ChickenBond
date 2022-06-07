pragma solidity ^0.8.10;

import "./ExternalContracts/MockPickleJar.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/DevTestSetup.sol";


contract LQTYChickenBondManagerDevOnlyTest is BaseTest, DevTestSetup {
    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Pickle jar gets some yield
        uint256 initialYield = 1e18;
        MockPickleJar(address(pickleJar)).harvest(initialYield);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedBLQTY_A = chickenBondManager.calcAccruedBLQTY(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lqtyToken.balanceOf(address(curveLiquidityGauge)), initialYield + chickenInFeeAmount, 2, "Balance of rewards contract doesn't match");

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
        assertEq(lqtyToken.balanceOf(address(curveLiquidityGauge)), chickenInFeeAmount, "Balance of rewards contract doesn't match");

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

        // Pickle jar gets some yield
        uint256 initialYield = 1e18;
        MockPickleJar(address(pickleJar)).harvest(initialYield);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(bLQTYToken.balanceOf(A));
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // make sure A withdraws Y tokens, otherwise would get part of the new harvest!
        vm.startPrank(A);
        pickleJar.withdraw(pickleJar.balanceOf(A));
        vm.stopPrank();

        // Pickle jar gets some yield
        uint256 secondYield = 1e18;
        MockPickleJar(address(pickleJar)).harvest(secondYield);

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
            5,
            "Balance of rewards contract doesn't match"
        );
        // check bLQTY B balance
        assertEq(bLQTYToken.balanceOf(B), accruedBLQTY_B, "bLQTY balance of B doesn't match");
    }
}
