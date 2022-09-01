pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";

contract ChickenBondManagerMainnetGaugeTest is BaseTest, MainnetTestSetup {
    // Helper to get the "prankster" address, i.e. the address where calls are being sent from.
    // Should be called externally, as in `this.getCurrentPrankster()`.
    function getCurrentPrankster() external view returns (address) {
        return msg.sender;
    }

    function approveTokens() internal {
        lusdToken.approve(address(chickenBondManager), type(uint256).max);
        lusdToken.approve(address(bLUSDCurvePool), type(uint256).max);
        bLUSDToken.approve(address(bLUSDCurvePool), type(uint256).max);
        bLUSDCurveToken.approve(address(curveLiquidityGauge), type(uint256).max);
    }

    function generateLUSDRewardForGaugeByChickeningIn()
        internal
        returns (uint256 generatedLUSDReward)
    {
        uint256 bondAmount = 100_000e18;
        deal(address(lusdToken), this.getCurrentPrankster(), bondAmount);
        uint256 bondID = chickenBondManager.createBond(bondAmount);
        generatedLUSDReward = bondAmount * CHICKEN_IN_AMM_FEE / 1e18;

        // If this is to be the first chicken-in, we must wait until the bootstrap period is over
        if (bLUSDToken.totalSupply() == 0) {
            vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);
        }

        uint256 gaugeLUSDBefore = lusdToken.balanceOf(address(curveLiquidityGauge));
        chickenBondManager.chickenIn(bondID);
        uint256 gaugeLUSDIncrease = lusdToken.balanceOf(address(curveLiquidityGauge)) - gaugeLUSDBefore;

        assertEqDecimal(gaugeLUSDIncrease, generatedLUSDReward, 18);
    }

    function addAllBLUSDAsLiquidity(uint256 lusdPerBLUSD) internal returns (uint256 lp) {
        uint256 bLUSDAmount = bLUSDToken.balanceOf(this.getCurrentPrankster());
        uint256 lusdAmount = bLUSDAmount * lusdPerBLUSD / 1e18;
        deal(address(lusdToken), this.getCurrentPrankster(), lusdAmount);
        lp = bLUSDCurvePool.add_liquidity([bLUSDAmount, lusdAmount], 0);
    }

    function claimRewards() internal returns (uint256 lusdReceived) {
        uint256 lusdBefore = lusdToken.balanceOf(this.getCurrentPrankster());
        curveLiquidityGauge.claim_rewards();
        lusdReceived = lusdToken.balanceOf(this.getCurrentPrankster()) - lusdBefore;
    }

    function testGaugeRewardsLPsWithLUSD() public {
        vm.startPrank(A);
        {
            approveTokens();
            uint256 generatedLUSDReward = generateLUSDRewardForGaugeByChickeningIn();
            uint256 lp = addAllBLUSDAsLiquidity(bLUSDCurvePool.price_scale());

            curveLiquidityGauge.deposit(lp);
            assertEqDecimal(curveLiquidityGauge.balanceOf(A), lp, 18);

            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD, generatedLUSDReward / 7, 1000);

            uint256 lusdReceived = claimRewards();
            assertEqDecimal(lusdReceived, claimableLUSD, 18);
        }
        vm.stopPrank();
    }

    /*
      Gauge cannot be killed with the permissionless Gauge Manager Proxy
    function testGaugeContinuesToRewardLUSDAfterKilled() public {
        uint256 generatedLUSDReward1;
        uint256 generatedLUSDReward2;

        vm.startPrank(A);
        {
            approveTokens();
            generatedLUSDReward1 = generateLUSDRewardForGaugeByChickeningIn();
            uint256 lp = addAllBLUSDAsLiquidity(bLUSDCurvePool.price_scale());

            curveLiquidityGauge.deposit(lp);
            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD, generatedLUSDReward1 / 7, 1000);
        }
        vm.stopPrank();

        // Let's suppose the gauge is killed by admins
        vm.startPrank(curveGaugeManagerAddress);
        curveLiquidityGauge.set_killed(true);
        vm.stopPrank();

        vm.startPrank(A);
        {
            // Verify that it continues to hand out rewards
            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD1 = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD1, generatedLUSDReward1 * 2 / 7, 1000);

            // Generate more rewards
            generatedLUSDReward2 = generateLUSDRewardForGaugeByChickeningIn();

            // Verify that the newly generated rewards are also handed out
            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD2 = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            uint256 remainingLUSD = generatedLUSDReward1 - claimableLUSD1 + generatedLUSDReward2;
            assertRelativeError(claimableLUSD2, claimableLUSD1 + remainingLUSD / 7, 1000);

            // Verify that rewards can still be claimed
            uint256 lusdReceived = claimRewards();
            assertEqDecimal(lusdReceived, claimableLUSD2, 18);
        }
        vm.stopPrank();
    }
    */

    function testRewardsCanStillBeClaimedAfterWithdrawal() public {
        vm.startPrank(A);
        {
            approveTokens();
            uint256 generatedLUSDReward = generateLUSDRewardForGaugeByChickeningIn();
            uint256 lp = addAllBLUSDAsLiquidity(bLUSDCurvePool.price_scale());

            // Stake for 1 day
            curveLiquidityGauge.deposit(lp);
            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD, generatedLUSDReward / 7, 1000);

            // Stop staking
            curveLiquidityGauge.withdraw(lp);
            assertEqDecimal(bLUSDCurveToken.balanceOf(A), lp, 18);

            // Claimable LUSD is still the same
            vm.warp(block.timestamp + 1 days);
            claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD, generatedLUSDReward / 7, 1000);

            // Verify that rewards can still be claimed
            uint256 lusdReceived = claimRewards();
            assertEqDecimal(lusdReceived, claimableLUSD, 18);
        }
        vm.stopPrank();
    }

    function testInitialRewardsAreLost() public {
        vm.startPrank(A);
        {
            approveTokens();
            uint256 generatedLUSDReward = generateLUSDRewardForGaugeByChickeningIn();
            uint256 lp = addAllBLUSDAsLiquidity(bLUSDCurvePool.price_scale());

            // No one stakes for the first half day
            vm.warp(block.timestamp + 12 hours);

            // Stake for enough time for all rewards to run out
            curveLiquidityGauge.deposit(lp);
            vm.warp(block.timestamp + 10 days);
            uint256 claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));

            // Only 6.5/7ths of the generated reward is claimable,
            // half a day's worth of rewards were lost
            assertRelativeError(claimableLUSD, generatedLUSDReward * 13 / 14, 1000);
        }
        vm.stopPrank();
    }

    function testRewardsAreLostWhenEveryoneStopsStaking() public {
        uint256 generatedLUSDReward;
        uint256 lp;

        vm.startPrank(A);
        {
            approveTokens();
            generatedLUSDReward = generateLUSDRewardForGaugeByChickeningIn();
            lp = addAllBLUSDAsLiquidity(bLUSDCurvePool.price_scale());

            // Stake for 1 day
            curveLiquidityGauge.deposit(lp);
            vm.warp(block.timestamp + 1 days);
            uint256 claimableLUSD = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
            assertRelativeError(claimableLUSD, generatedLUSDReward / 7, 1000);

            // Withdraw and send all LP to second user
            curveLiquidityGauge.withdraw(lp);
            bLUSDCurveToken.transfer(B, lp);
        }
        vm.stopPrank();

        // Some time passes while no one is staking in the gauge
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(B);
        {
            approveTokens();

            // Stake for 1 day
            curveLiquidityGauge.deposit(lp);
            vm.warp(block.timestamp + 1 days);
        }
        vm.stopPrank();

        uint256 claimableLUSD_A = curveLiquidityGauge.claimable_reward(A, address(lusdToken));
        uint256 claimableLUSD_B = curveLiquidityGauge.claimable_reward(B, address(lusdToken));

        // A has only earned 1/7th of the total generated LUSD reward and B is earning nothing.
        // 6/7ths of the reward was lost.
        assertRelativeError(claimableLUSD_A, generatedLUSDReward / 7, 1000);
        assertEq(claimableLUSD_B, 0);
    }
}
