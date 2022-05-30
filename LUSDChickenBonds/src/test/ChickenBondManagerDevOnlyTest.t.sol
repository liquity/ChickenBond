pragma solidity ^0.8.10;

import "../ExternalContracts/MockYearnVault.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/DevTestSetup.sol";


contract ChickenBondManagerDevOnlyTest is BaseTest, DevTestSetup {
    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        MockYearnVault(address(yearnSPVault)).harvest(initialYield);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), initialYield + chickenInFeeAmount, 2, "Balance of rewards contract doesn't match");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 chickenInFeeAmount = _getChickenInFeeForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertEq(lusdToken.balanceOf(address(curveLiquidityGauge)), chickenInFeeAmount, "Balance of rewards contract doesn't match");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
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
        uint256 initialYield = 1e18;
        MockYearnVault(address(yearnSPVault)).harvest(initialYield);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(sLUSDToken.balanceOf(A));
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // make sure A withdraws Y tokens, otherwise would get part of the new harvest!
        vm.startPrank(A);
        yearnSPVault.withdraw(yearnSPVault.balanceOf(A));
        vm.stopPrank();

        // Yearn LUSD Vault gets some yield
        uint256 secondYield = 4e18;
        MockYearnVault(address(yearnSPVault)).harvest(secondYield);

        // B chickens in
        vm.startPrank(B);
        uint256 accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        uint256 yieldFromFirstChickenInRedemptionFee = sLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            initialYield + secondYield + 2 * chickenInFeeAmount + yieldFromFirstChickenInRedemptionFee,
            5,
            "Balance of rewards contract doesn't match"
        );
        // check sLUSD B balance
        assertEq(sLUSDToken.balanceOf(B), accruedSLUSD_B, "sLUSD balance of B doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionAndCurveHarvestTransfersToRewardsContract() external {
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

        // shift 50% to Curve
        MockCurvePool(address(curvePool)).setNextPrankPrice(105e16);
        shiftFractionFromSPToCurve(2);

        uint256 initialPermanentLUSDInSP = chickenBondManager.getPermanentLUSDInSP();
        uint256 initialPermanentLUSDInCurve = chickenBondManager.getPermanentLUSDInCurve();

        // A redeems full
        uint256 redemptionFeePercentage = chickenBondManager.calcRedemptionFeePercentage(1e18);
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondManager.redeem(sLUSDToken.balanceOf(A));
        // A withdraws from Yearn to make math simpler, otherwise harvest would be shared
        yearnCurveVault.withdraw(yearnCurveVault.balanceOf(A));
        vm.stopPrank();

        // harvest curve
        uint256 prevValue = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        MockYearnVault(address(yearnCurveVault)).harvest(1000e18);
        uint256 curveYield = chickenBondManager.calcTotalYearnCurveVaultShareValue() - prevValue;

        // create bond
        A_bondID = createBondForUser(A, bondAmount2);

        // wait 100 days more
        vm.warp(block.timestamp + 100 days);

        // A chickens in
        uint256 accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);

        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // checks
        // Acquired in SP vault
        assertApproximatelyEqual(
            chickenBondManager.getAcquiredLUSDInSP(),
            accruedSLUSD,
            1,
            "Acquired LUSD in SP mismatch"
        );
        // Permanent in SP vault
        assertApproximatelyEqual(
            chickenBondManager.getPermanentLUSDInSP(),
            initialPermanentLUSDInSP + _getAmountMinusChickenInFee(bondAmount2) - accruedSLUSD,
            1,
            "Permanent LUSD in SP mismatch"
        );

        // Acquired in Curve vault
        assertApproximatelyEqual(
            chickenBondManager.getAcquiredLUSDInCurve(),
            0,
            20,
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
        //uint256 yieldFromFirstChickenInRedemptionFee = sLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(curveLiquidityGauge)),
            //curveYield + _getChickenInFeeForAmount(bondAmount1) + _getChickenInFeeForAmount(bondAmount2) + yieldFromFirstChickenInRedemptionFee,
            curveYield + _getChickenInFeeForAmount(bondAmount1) + _getChickenInFeeForAmount(bondAmount2) + sLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18,
            250,
            "Rewards contract balance mismatch"
        );
    }
}
