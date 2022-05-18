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
        uint256 prevValue = chickenBondManager.calcYearnLUSDVaultShareValue();
        vm.startPrank(keeper);
        StrategyAPI(strategy).harvest();

        // some time passes to unlock profits
        vm.warp(block.timestamp + 600);
        vm.stopPrank();
        uint256 valueIncrease = chickenBondManager.calcYearnLUSDVaultShareValue() - prevValue;

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
}
