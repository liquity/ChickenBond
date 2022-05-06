pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../LPRewards/Unipool.sol";
import "./TestContracts/BaseTest.sol";


contract UnipoolTest is BaseTest {
    IERC20 uniToken;
    IERC20 rewardToken;
    Unipool unipool;

    function setUp() public {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();
        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);

        uniToken = new ERC20("UNI LP token", "UNI");
        rewardToken = new ERC20("Rewart token", "RWR");

        unipool = new Unipool(address(rewardToken), address(uniToken));

        // Give some LUSD to test accounts
        tip(address(uniToken), A, 100e18);
        tip(address(uniToken), B, 100e18);
        tip(address(uniToken), C, 100e18);
        tip(address(uniToken), D, 100e18);
    }

    function _addRewards(address _provider, uint256 _amount) internal {
        tip(address(rewardToken), _provider, _amount);
        vm.startPrank(_provider);
        rewardToken.approve(address(unipool), _amount);
        unipool.pullRewardAmount(_amount);
        vm.stopPrank();
    }

    function testTwoStakersSameStakeSameDurationSimultaneous() external {
        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmount = 1;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(C, totalReward);

        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmount);
        unipool.stake(stakeAmount);
        vm.stopPrank();

        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmount);
        unipool.stake(stakeAmount);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        uint256 expectedRewardPerToken = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 1e18 / 2 / stakeAmount;
        uint256 expectedEarn = expectedRewardPerToken * stakeAmount / 1e18;
        assertEq(unipool.rewardPerToken(), expectedRewardPerToken);
        assertEq(unipool.totalSupply(), 2 * stakeAmount);
        assertEq(unipool.earned(A), expectedEarn);
        assertEq(unipool.earned(B), expectedEarn);

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarn, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarn, "B balance doesn't match");
    }

    function testTwoStakersSameStakeSameDurationOverlap() external {
        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmount = 1;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(C, totalReward);

        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmount);
        unipool.stake(stakeAmount);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmount);
        unipool.stake(stakeAmount);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);
        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 2 / 3;
        uint256 expectedEarnA = expectedReward * 3 / 4;
        uint256 expectedEarnB = expectedReward / 4;
        assertEq(unipool.totalSupply(), 2 * stakeAmount, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");

        // A withdraws
        vm.startPrank(A);
        unipool.withdraw(stakeAmount);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);

        uint256 expectedRewardPerToken = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 1e18 / 2 / stakeAmount;
        uint256 expectedEarn = expectedRewardPerToken * stakeAmount / 1e18;
        assertEq(unipool.totalSupply(), stakeAmount, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarn, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarn, "B rewards don't match");

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarn, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarn, "B balance doesn't match");
    }

    function testTwoStakersDifferentStakeSameDurationOverlap() external {
        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(C, totalReward);

        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);
        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 2 / 3;
        uint256 expectedEarnA = expectedReward * 5 / 8;
        uint256 expectedEarnB = expectedReward * 3 / 8;
        assertEq(unipool.totalSupply(), stakeAmountA + stakeAmountB, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");

        // A withdraws
        vm.startPrank(A);
        unipool.withdraw(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 3);

        expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime;
        expectedEarnA = expectedReward * 5 / 12;
        expectedEarnB = expectedReward * 7 / 12;
        assertEq(unipool.totalSupply(), stakeAmountB, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertApproximatelyEqual(unipool.earned(B), expectedEarnB, 1000, "B rewards don't match");

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertApproximatelyEqual(rewardToken.balanceOf(B), expectedEarnB, 1000, "B balance doesn't match");
    }

    function testTwoStakersDifferentStakeDifferentDurationOverlap() external {
        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(C, totalReward);

        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 2);
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);
        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 3 / 4;
        uint256 expectedEarnA = expectedReward * 9 / 12;
        uint256 expectedEarnB = expectedReward * 3 / 12;
        assertEq(unipool.totalSupply(), stakeAmountA + stakeAmountB, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");

        // A withdraws
        vm.startPrank(A);
        unipool.withdraw(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);

        expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime;
        expectedEarnA = expectedReward * 9 / 16;
        expectedEarnB = expectedReward * 7 / 16;
        assertEq(unipool.totalSupply(), stakeAmountB, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarnB, "B balance doesn't match");
    }

    function testThreeStakersDifferentStakeDifferentDurationOverlap() external {
        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 stakeAmountC = 4;
        uint256 totalStake = stakeAmountA + stakeAmountB + stakeAmountC;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(D, totalReward);

        // A stakes
        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);
        // B stakes
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);
        // C stakes
        vm.startPrank(C);
        uniToken.approve(address(unipool), stakeAmountC);
        unipool.stake(stakeAmountC);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);
        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 3 / 4;
        uint256 expectedEarnA = expectedReward * 11 / 24; // (1/4 + 1/4 * 1/4 + 1/8 * 1/4) / (3/4)
        uint256 expectedEarnB = expectedReward * 3 / 8; // (3/4 * 1/4 + 3/8 * 1/4) / (3/4)
        uint256 expectedEarnC = expectedReward * 1 / 6; // (1/2 * 1/4) / (3/4)
        assertEq(unipool.totalSupply(), totalStake, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // B withdraws
        vm.startPrank(B);
        unipool.withdraw(stakeAmountB);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime / 4);

        expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime;
        expectedEarnA = expectedReward * 63 / 160; // 1/4 + 1/4 * 1/4 + 1/8 * 1/4 + 1/5 * 1/4
        expectedEarnB = expectedReward * 9 / 32; // 3/4 * 1/4 + 3/8 * 1/4
        expectedEarnC = expectedReward * 13 / 40; // 1/2 * 1/4 + 4/5 * 1/4
        assertEq(unipool.totalSupply(), stakeAmountA + stakeAmountC, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(C);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarnB, "B balance doesn't match");
        assertEq(rewardToken.balanceOf(C), expectedEarnC, "C balance doesn't match");
    }

    function testThreeStakersWithGaps() external {
        //
        // 1x: +-------+               |
        // 3x:                +------+ |
        // 4x:                         |  +------...
        //                             +-> end of initial duration

        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 stakeAmountC = 4;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(D, totalReward);

        // A stakes
        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // A withdraws
        unipool.withdraw(stakeAmountA);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // B stakes
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // B withdraws
        unipool.withdraw(stakeAmountB);
        vm.stopPrank();

        // time goes by until period finish
        vm.warp(block.timestamp + unipool.INITIAL_DURATION() - 3 * elapsedTime);

        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 2;
        uint256 expectedEarnA = expectedReward / 2;
        uint256 expectedEarnB = expectedReward / 2;
        uint256 expectedEarnC = 0;
        assertEq(unipool.totalSupply(), 0, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // C stakes
        vm.startPrank(C);
        uniToken.approve(address(unipool), stakeAmountC);
        unipool.stake(stakeAmountC);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + 2 * elapsedTime);

        expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 4;
        expectedEarnA = expectedReward / 4;
        expectedEarnB = expectedReward / 4;
        expectedEarnC = expectedReward / 2;
        assertEq(unipool.totalSupply(), stakeAmountC, "Total supply doesn't match");
        assertEq(unipool.earned(A), expectedEarnA, "A rewards don't match");
        assertEq(unipool.earned(B), expectedEarnB, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // claim
        vm.startPrank(A);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(B);
        unipool.claimReward();
        vm.stopPrank();

        vm.startPrank(C);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarnB, "B balance doesn't match");
        assertEq(rewardToken.balanceOf(C), expectedEarnC, "C balance doesn't match");
    }

    function testThreeStakersWithGapsAndInBetweenClaims() external {
        //
        // 1x: +-------+               |
        // 3x:                +------+ |
        // 4x:                         |  +------...
        //                             +-> end of initial duration

        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 totalReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 stakeAmountC = 4;
        uint256 elapsedTime = 600;

        // fund rewards contract
        _addRewards(D, totalReward);

        // A stakes
        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // A withdraws
        unipool.withdrawAndClaim();
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // B stakes
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // B withdraws
        unipool.withdrawAndClaim();
        vm.stopPrank();

        // time goes by until period finish
        vm.warp(block.timestamp + unipool.INITIAL_DURATION() - 3 * elapsedTime);

        uint256 expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 2;
        uint256 expectedEarnA = expectedReward / 2;
        uint256 expectedEarnB = expectedReward / 2;
        uint256 expectedEarnC = 0;
        assertEq(unipool.totalSupply(), 0, "Total supply doesn't match");
        assertEq(unipool.earned(A), 0, "A rewards don't match");
        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertEq(unipool.earned(B), 0, "B rewards don't match");
        assertEq(rewardToken.balanceOf(B), expectedEarnB, "B balance doesn't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // time goes by
        vm.warp(block.timestamp + elapsedTime);

        // C stakes
        vm.startPrank(C);
        uniToken.approve(address(unipool), stakeAmountC);
        unipool.stake(stakeAmountC);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + 2 * elapsedTime);

        expectedReward = totalReward / unipool.INITIAL_DURATION() * elapsedTime * 4;
        expectedEarnA = expectedReward / 4;
        expectedEarnB = expectedReward / 4;
        expectedEarnC = expectedReward / 2;
        assertEq(unipool.totalSupply(), stakeAmountC, "Total supply doesn't match");
        assertEq(unipool.earned(A), 0, "A rewards don't match");
        assertEq(unipool.earned(B), 0, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // claim
        vm.startPrank(C);
        unipool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(A), expectedEarnA, "A balance doesn't match");
        assertEq(rewardToken.balanceOf(B), expectedEarnB, "B balance doesn't match");
        assertEq(rewardToken.balanceOf(C), expectedEarnC, "C balance doesn't match");
    }

    function testThreeStakersWithGapsClaimsAndExtraRewards() external {
        //
        // 1x: +-------+               |
        // 3x:                +------+ |
        // 4x:                         |  +------...
        //                             +-> end of initial duration

        assert(unipool.rewardPerToken() == 0);
        assert(unipool.earned(A) == 0);
        assert(unipool.earned(B) == 0);

        uint256 initialReward = 100e18;
        uint256 stakeAmountA = 1;
        uint256 stakeAmountB = 3;
        uint256 stakeAmountC = 4;
        uint256 ONE_DAY = 86400;

        // fund rewards contract
        _addRewards(D, initialReward);

        // A stakes
        vm.startPrank(A);
        uniToken.approve(address(unipool), stakeAmountA);
        unipool.stake(stakeAmountA);

        // time goes by
        vm.warp(block.timestamp + 5 * ONE_DAY);

        // A withdraws
        unipool.withdrawAndClaim();
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // more rewards - this will increase duration
        uint256 previousRewardRate = unipool.rewardRate();
        uint256 previousDuration = unipool.periodFinish() - block.timestamp;
        _addRewards(D, initialReward / 10);
        assertTrue(unipool.rewardRate() == previousRewardRate, "Reward rate should stay constant");
        assertTrue(unipool.periodFinish() - block.timestamp > previousDuration, "Duration should increase");

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // B stakes
        vm.startPrank(B);
        uniToken.approve(address(unipool), stakeAmountB);
        unipool.stake(stakeAmountB);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // more rewards - this will increase reward rate
        previousRewardRate = unipool.rewardRate();
        //previousDuration = unipool.periodFinish() - block.timestamp;
        _addRewards(D, initialReward);
        assertTrue(unipool.rewardRate() > previousRewardRate, "Reward rate should increase");
        assertTrue(unipool.periodFinish() - block.timestamp == unipool.INITIAL_DURATION(), "Wrong duration");

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // B withdraws
        vm.startPrank(B);
        unipool.withdrawAndClaim();
        vm.stopPrank();

        // time goes by until period finish
        vm.warp(unipool.periodFinish());

        uint256 expectedEarnA = initialReward * 5 * ONE_DAY / unipool.INITIAL_DURATION();
        uint256 expectedEarnB = initialReward * 2957142857 / 1000000000 * ONE_DAY / unipool.INITIAL_DURATION(); // (2+(36+4.2)/42)
        uint256 expectedEarnC = 0;
        assertEq(unipool.totalSupply(), 0, "Total supply doesn't match");
        assertEq(unipool.earned(A), 0, "A rewards don't match");
        assertApproximatelyEqual(rewardToken.balanceOf(A), expectedEarnA, 500000, "A balance doesn't match");
        assertEq(unipool.earned(B), 0, "B rewards don't match");
        assertApproximatelyEqual(rewardToken.balanceOf(B), expectedEarnB, 500000000, "B balance doesn't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // more rewards - period is over, but there are pending rewards to carry over
        assertTrue(unipool.periodFinish() <= block.timestamp, "Reward period should be over");
        previousRewardRate = unipool.rewardRate();
        _addRewards(D, initialReward / 10);
        // only 1 day of the previous day was spent, so 1/42 of the previous reward is used to reach INITIAL_DURATION, the rest to increase rate
        uint256 expectedRewardRate = previousRewardRate + (initialReward / 10  - previousRewardRate * ONE_DAY) / unipool.INITIAL_DURATION();
        assertEq(unipool.rewardRate(), expectedRewardRate, "Wrong reward rate");
        assertEq(unipool.periodFinish() - block.timestamp, unipool.INITIAL_DURATION(), "Wrong duration");

        // C stakes
        vm.startPrank(C);
        uniToken.approve(address(unipool), stakeAmountC);
        unipool.stake(stakeAmountC);
        vm.stopPrank();

        // time goes by
        vm.warp(block.timestamp + 2 * ONE_DAY);

        expectedEarnC = expectedRewardRate * 2 * ONE_DAY;
        assertEq(unipool.totalSupply(), stakeAmountC, "Total supply doesn't match");
        assertEq(unipool.earned(A), 0, "A rewards don't match");
        assertEq(unipool.earned(B), 0, "B rewards don't match");
        assertEq(unipool.earned(C), expectedEarnC, "C rewards don't match");

        // claim
        vm.startPrank(C);
        unipool.claimReward();
        vm.stopPrank();

        assertApproximatelyEqual(rewardToken.balanceOf(A), expectedEarnA, 500000, "A balance doesn't match");
        assertApproximatelyEqual(rewardToken.balanceOf(B), expectedEarnB, 500000000, "B balance doesn't match");
        assertEq(rewardToken.balanceOf(C), expectedEarnC, "C balance doesn't match");


        // time goes by, until period is over, as C was staked, rewards were consumed
        vm.warp(unipool.periodFinish() + 1);

        // exit
        vm.startPrank(C);
        unipool.withdrawAndClaim();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(C), expectedRewardRate * unipool.INITIAL_DURATION(), "C balance doesn't match");

        // time goes by
        vm.warp(block.timestamp + ONE_DAY);

        // top up again, start over
        _addRewards(D, initialReward);
        assertEq(unipool.rewardRate(), initialReward / unipool.INITIAL_DURATION(), "Wrong reward rate");
        assertEq(unipool.periodFinish() - block.timestamp, unipool.INITIAL_DURATION(), "Wrong duration");
    }
}
