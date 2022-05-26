pragma solidity ^0.8.10;

import "../ExternalContracts/MockYearnVault.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/DevTestSetup.sol";


contract ChickenBondManagerDevOnlyTest is BaseTest, DevTestSetup {
    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 taxAmount = _getTaxForAmount(bondAmount);

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 initialYield = 1e18;
        MockYearnVault(address(yearnLUSDVault)).harvest(initialYield);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        assertApproximatelyEqual(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), initialYield + taxAmount, 2, "Balance of rewards contract doesn't match");

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
        assertEq(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), taxAmount, "Balance of rewards contract doesn't match");

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
        uint256 initialYield = 1e18;
        MockYearnVault(address(yearnLUSDVault)).harvest(initialYield);

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
        yearnLUSDVault.withdraw(yearnLUSDVault.balanceOf(A));
        vm.stopPrank();

        // Yearn LUSD Vault gets some yield
        uint256 secondYield = 4e18;
        MockYearnVault(address(yearnLUSDVault)).harvest(secondYield);

        // B chickens in
        vm.startPrank(B);
        uint256 accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        uint256 yieldFromFirstChickenInRedemptionFee = sLUSDBalance * backingRatio / 1e18 * (1e18 - redemptionFeePercentage) / 1e18;
        assertApproximatelyEqual(
            lusdToken.balanceOf(address(sLUSDLPRewardsStaking)),
            initialYield + secondYield + 2 * taxAmount + yieldFromFirstChickenInRedemptionFee,
            5,
            "Balance of rewards contract doesn't match"
        );
        // check sLUSD B balance
        assertEq(sLUSDToken.balanceOf(B), accruedSLUSD_B, "sLUSD balance of B doesn't match");
    }
}
