pragma solidity ^0.8.10;

import "../ExternalContracts/MockYearnVault.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/DevTestSetup.sol";


contract ChickenBondManagerDevOnlyTest is BaseTest, DevTestSetup {
    function testFirstChickenInTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;

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
        (uint256 reserves0, uint256 reserves1,) = IUniswapV2Pair(uniswapV2Factory.getPair(address(sLUSDToken), address(lusdToken))).getReserves();
        assertApproximatelyEqual(reserves0, initialYield / 2, 1, "Reserves in AMM for first token don't match");
        assertApproximatelyEqual(reserves1, initialYield / 2, 1, "Reserves in AMM for first token don't match");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
    }

    function testFirstChickenInWithoutInitialYield() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        uint256 accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(A_bondID);
        chickenBondManager.chickenIn(A_bondID);

        // Checks
        // Uniswap pair wasn’t even created
        assertEq(uniswapV2Factory.getPair(address(sLUSDToken), address(lusdToken)), address(0), "Uniswap pair shouldn't exist");

        // check sLUSD A balance
        assertEq(sLUSDToken.balanceOf(A), accruedSLUSD_A, "sLUSD balance of A doesn't match");
    }

    function testFirstChickenInAfterRedemptionDepletionTransfersToRewardsContract() public {
        // A creates bond
        uint256 bondAmount = 10e18;

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
        vm.startPrank(A);
        chickenBondManager.redeem(sLUSDToken.balanceOf(A));
        vm.stopPrank();

        vm.warp(block.timestamp + 600);

        // Yearn LUSD Vault gets some yield
        uint256 secondYield = 4e18;
        MockYearnVault(address(yearnLUSDVault)).harvest(secondYield);

        // B chickens in
        vm.startPrank(B);
        uint256 accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(B_bondID);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Checks
        // Amounts provided as liquidity to the Uniswap pair will still be the ones from the first chicken in,
        // as precisely that permanent liquidity prevents the total supply of sLUSD to become zero
        (uint256 reserves0, uint256 reserves1,) = IUniswapV2Pair(uniswapV2Factory.getPair(address(sLUSDToken), address(lusdToken))).getReserves();
        assertApproximatelyEqual(reserves0, initialYield / 2, 2, "Reserves in AMM for first token don't match");
        assertApproximatelyEqual(reserves1, initialYield / 2, 2, "Reserves in AMM for first token don't match");
        // check sLUSD B balance
        assertEq(sLUSDToken.balanceOf(B), accruedSLUSD_B, "sLUSD balance of B doesn't match");
    }
}
