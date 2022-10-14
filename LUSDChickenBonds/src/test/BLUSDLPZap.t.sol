pragma solidity ^0.8.11;

import "../BLUSDLPZap.sol";
import "./TestContracts/BaseTest.sol";


contract BLUSDLPZapTest is BaseTest {
    BLUSDLPZap bLUSDLPZap;
    IERC20 lusd3CRVPool;
    IERC20 bLUSDLUSD3CRVLPToken;
    ICurveCryptoPool bLUSDLUSD3CRVPool;
    ICurveLiquidityGaugeV5 bLUSDGauge;

    struct TokenBalances {
        uint256 lusdBalance;
        uint256 bLUSDBalance;
        uint256 lusd3CRVPoolBalance;
        uint256 bLUSDPoolBalance;
        uint256 bLUSDGaugeBalance;
    }

    function setUp() public {
        bLUSDLPZap = new BLUSDLPZap();
        lusdToken = IERC20Permit(address(bLUSDLPZap.lusdToken()));
        bLUSDToken = BLUSDToken(address(bLUSDLPZap.bLUSDToken()));
        lusd3CRVPool = bLUSDLPZap.lusd3CRVPool();
        bLUSDLUSD3CRVLPToken = bLUSDLPZap.bLUSDLUSD3CRVLPToken();
        bLUSDLUSD3CRVPool = bLUSDLPZap.bLUSDLUSD3CRVPool();
        bLUSDGauge = bLUSDLPZap.bLUSDGauge();

        accounts = new Accounts();
        createAccounts();
        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);
    }

    // cache initial balances
    function _getInitialBalances() internal view returns(TokenBalances memory tokenBalances) {
        tokenBalances.lusdBalance = lusdToken.balanceOf(address(bLUSDLPZap));
        tokenBalances.bLUSDBalance = bLUSDToken.balanceOf(address(bLUSDLPZap));
        tokenBalances.lusd3CRVPoolBalance = lusd3CRVPool.balanceOf(address(bLUSDLPZap));
        tokenBalances.bLUSDPoolBalance = bLUSDLUSD3CRVLPToken.balanceOf(address(bLUSDLPZap));
        tokenBalances.bLUSDGaugeBalance = bLUSDGauge.balanceOf(address(bLUSDLPZap));
    }

    function _checkBalances(TokenBalances memory _tokenInitialBalances) internal view {
        require(_tokenInitialBalances.lusdBalance == lusdToken.balanceOf(address(bLUSDLPZap)));
        require(_tokenInitialBalances.bLUSDBalance == bLUSDToken.balanceOf(address(bLUSDLPZap)));
        require(_tokenInitialBalances.lusd3CRVPoolBalance == lusd3CRVPool.balanceOf(address(bLUSDLPZap)));
        require(_tokenInitialBalances.bLUSDPoolBalance == bLUSDLUSD3CRVLPToken.balanceOf(address(bLUSDLPZap)));
        require(_tokenInitialBalances.bLUSDGaugeBalance == bLUSDGauge.balanceOf(address(bLUSDLPZap)));
    }

    function _dealAndApprove(uint256 bLUSDAmount, uint256 lusdAmount) internal {
        // bLUSD
        if (bLUSDAmount > 0) {
            deal(address(bLUSDToken), A, bLUSDAmount);
            bLUSDToken.approve(address(bLUSDLPZap), bLUSDAmount);
        }
        // LUSD
        if (lusdAmount > 0) {
            deal(address(lusdToken), A, lusdAmount);
            lusdToken.approve(address(bLUSDLPZap), lusdAmount);
        }
    }

    function _addLiquidity(uint256 bLUSDAmount, uint256 lusdAmount, uint256 minLPAmount) internal returns (uint256) {
        vm.startPrank(A);
        _dealAndApprove(bLUSDAmount, lusdAmount);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);

        // add liquidity
        uint256 lpAmount = bLUSDLPZap.addLiquidity(bLUSDAmount, lusdAmount, minLPAmount);
        vm.stopPrank();

        assertEq(lpAmount, bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, "LP tokens mismatch");

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);

        return lpAmount;
    }

    function testAddLiquidityGetsLPTokensNoMin() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        uint256 initialLUSD3CRVBalance = lusd3CRVPool.balanceOf(A);
        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        assertEq(lusd3CRVPool.balanceOf(A) - initialLUSD3CRVBalance, 0, "User should not receive 3pool LP tokens");
        assertGt(lpAmount, 0, "User should receive LP tokens");
    }

    function testAddLiquidityGetsMinLPTokens() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 minLPAmount = 1145e18 * 99 / 100; // add some safety thresholds, as mainnet state can vary

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, minLPAmount);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        assertGt(lpAmount, minLPAmount, "Not enough LP tokens received");
    }

    function testAddLiquidityFailsIfNotMinLPTokens() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 minLPAmount = 1146e18 * 101 / 100; // add some safety thresholds, as mainnet state can vary

        vm.startPrank(A);
        _dealAndApprove(bLUSDAmount, lusdAmount);
        // add liquidity
        vm.expectRevert("Slippage");
        bLUSDLPZap.addLiquidity(bLUSDAmount, lusdAmount, minLPAmount);
        vm.stopPrank();
    }

    function testAddLiquiditySingleSidedBLUSD() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        // Initial liquidity must be dual sided
        _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 bLUSDAmount2 = bLUSDAmount / 10;
        uint256 minLPAmount = bLUSDLPZap.getMinLPTokens(bLUSDAmount2, 0);
        //console.log(minLPAmount, "minLPAmount");
        uint256 lpAmount = _addLiquidity(bLUSDAmount2, 0, minLPAmount);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A)  - initialbLUSDLUSD3CRVLPTokenBalance, "bLUSDLUSD3CRVLPToken received");
        assertGt(lpAmount, 0, "User should receive LP tokens");
    }

    function testAddLiquiditySingleSidedLUSD() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        // Initial liquidity must be dual sided
        _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 lusdAmount2 = lusdAmount / 10;
        uint256 minLPAmount = bLUSDLPZap.getMinLPTokens(0, lusdAmount2);
        //console.log(minLPAmount, "minLPAmount");
        uint256 lpAmount = _addLiquidity(0, lusdAmount2, minLPAmount);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A)  - initialbLUSDLUSD3CRVLPTokenBalance, "bLUSDLUSD3CRVLPToken received");
        assertGt(lpAmount, 0, "User should receive LP tokens");
    }

    function testAddLiquidityFailsIfBothZero() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        // Initial liquidity must be dual sided
        _addLiquidity(bLUSDAmount, lusdAmount, 0);

        vm.startPrank(A);
        vm.expectRevert("BLUSDLPZap: Cannot provide zero liquidity");
        bLUSDLPZap.addLiquidity(0, 0, 0);
        vm.stopPrank();
    }

    function testAddLiquidityAndStakeGetsGaugeTokens() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);
        uint256 initialbLUSDGaugeBalance = bLUSDGauge.balanceOf(A);

        vm.startPrank(A);
        _dealAndApprove(bLUSDAmount, lusdAmount);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        // add liquidity and stake
        bLUSDLPZap.addLiquidityAndStake(bLUSDAmount, lusdAmount, 0);
        vm.stopPrank();

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        //console.log(bLUSDGauge.balanceOf(A), "bLUSDGauge.balanceOf(A)");
        assertEq(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, 0, "User should not receive LP tokens");
        assertGt(bLUSDGauge.balanceOf(A) - initialbLUSDGaugeBalance, 1145, "User should receive LP tokens");
    }

    function testRemoveLiqudityBalancedNoMin() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 50e16;

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        uint256 initialBLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 initialLUSDBalance = lusdToken.balanceOf(A);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        (uint256 expectedBLUSDAmount, uint256 expectedLUSDAmount) = bLUSDLPZap.getMinWithdrawBalanced(withdrawAmount);

        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        bLUSDLPZap.removeLiquidityBalanced(withdrawAmount, 0, 0);
        vm.stopPrank();

        //console.log(bLUSDToken.balanceOf(A) - initialBLUSDBalance, "received bLUSD");
        //console.log(lusdToken.balanceOf(A) - initialLUSDBalance, "received LUSD");
        assertRelativeError(
            bLUSDToken.balanceOf(A) - initialBLUSDBalance,
            expectedBLUSDAmount,
            10,
            "BLUSD balance mismatch"
        );
        assertRelativeError(
            lusdToken.balanceOf(A) - initialLUSDBalance,
            expectedLUSDAmount,
            10,
            "LUSD balance mismatch"
        );

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);
    }

    function testRemoveLiqudityBalancedWithMinAmounts() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 50e16;

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        uint256 initialBLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 initialLUSDBalance = lusdToken.balanceOf(A);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        (uint256 expectedBLUSDAmount, uint256 expectedLUSDAmount) = bLUSDLPZap.getMinWithdrawBalanced(withdrawAmount);
        // rounding errors
        expectedBLUSDAmount = expectedBLUSDAmount - 2;
        expectedLUSDAmount = expectedLUSDAmount - 2;
        //console.log(expectedBLUSDAmount, "expectedBLUSDAmount");
        //console.log(expectedLUSDAmount, "expectedLUSDAmount");

        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        bLUSDLPZap.removeLiquidityBalanced(withdrawAmount, expectedBLUSDAmount, expectedLUSDAmount);
        vm.stopPrank();

        //console.log(bLUSDToken.balanceOf(A) - initialBLUSDBalance, "received bLUSD");
        //console.log(lusdToken.balanceOf(A) - initialLUSDBalance, "received LUSD");
        assertRelativeError(
            bLUSDToken.balanceOf(A) - initialBLUSDBalance,
            expectedBLUSDAmount,
            10,
            "BLUSD balance mismatch"
        );
        assertRelativeError(
            lusdToken.balanceOf(A) - initialLUSDBalance,
            expectedLUSDAmount,
            10,
            "LUSD balance mismatch"
        );

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);
    }

    function testRemoveLiqudityBalancedFailsIfNoMinBLUSDReached() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 50e16;

        uint256 expectedBLUSDAmount = bLUSDAmount * fractionToWithdraw / 1e18 + 1e18;

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        vm.expectRevert();
        bLUSDLPZap.removeLiquidityBalanced(withdrawAmount, expectedBLUSDAmount, 0);
        vm.stopPrank();
    }

    function testRemoveLiqudityBalancedFailsIfNoMinLUSDReached() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 50e16;

        uint256 expectedLUSDAmount = lusdAmount * fractionToWithdraw / 1e18 + 1e18;

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        vm.expectRevert();
        bLUSDLPZap.removeLiquidityBalanced(withdrawAmount, 0, expectedLUSDAmount);
        vm.stopPrank();
    }

    function testRemoveLiqudityLUSDNoMin() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 1e16; // small fraction, to avoid too much slippage

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        uint256 initialBLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 initialLUSDBalance = lusdToken.balanceOf(A);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        uint256 expectedLUSD = bLUSDLPZap.getMinWithdrawLUSD(withdrawAmount);

        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        bLUSDLPZap.removeLiquidityLUSD(withdrawAmount, 0);
        vm.stopPrank();

        assertEq(bLUSDToken.balanceOf(A) - initialBLUSDBalance, 0, "BLUSD received should be zero");
        //console.log(lusdToken.balanceOf(A) - initialLUSDBalance, "lusdToken.balanceOf(A) - initialLUSDBalance");
        //console.log(lusdAmount * fractionToWithdraw / 1e18, "lusdAmount * fractionToWithdraw / 1e18");
        //console.log(bLUSDAmount * fractionToWithdraw / 1e18, "bLUSDAmount * fractionToWithdraw / 1e18");
        //console.log(expectedLUSD, "expectedLUSD");
        //console.log(bLUSDLUSD3CRVPool.get_dy(0, 1, bLUSDAmount * fractionToWithdraw / 1e18), "bLUSDLUSD3CRVLPPool.get_dy(0, 1, bLUSDAmount * fractionToWithdraw / 1e18)");
        assertRelativeError(
            lusdToken.balanceOf(A) - initialLUSDBalance,
            expectedLUSD,
            1e3,
            "LUSD balance mismatch"
        );

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);
    }

    function testRemoveLiqudityLUSDWithMin() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 1e16; // small fraction, to avoid too much slippage

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        TokenBalances memory tokenInitialBalances = _getInitialBalances();

        uint256 initialBLUSDBalance = bLUSDToken.balanceOf(A);
        uint256 initialLUSDBalance = lusdToken.balanceOf(A);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        uint256 expectedLUSD = bLUSDLPZap.getMinWithdrawLUSD(withdrawAmount);
        //console.log(expectedLUSD, "expectedLUSD");

        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        bLUSDLPZap.removeLiquidityLUSD(withdrawAmount, expectedLUSD);
        vm.stopPrank();

        //console.log(lusdToken.balanceOf(A) - initialLUSDBalance, "lusdToken.balanceOf(A) - initialLUSDBalance");
        assertEq(bLUSDToken.balanceOf(A) - initialBLUSDBalance, 0, "BLUSD received should be zero");
        assertRelativeError(
            lusdToken.balanceOf(A) - initialLUSDBalance,
            expectedLUSD,
            1e15,
            "LUSD balance mismatch"
        );

        // check no tokens are left in the contract
        _checkBalances(tokenInitialBalances);
    }

    function testRemoveLiqudityLUSDFailsIfNoMinReached() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 fractionToWithdraw = 1e16; // small fraction, to avoid too much slippage

        uint256 lpAmount = _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 withdrawAmount = lpAmount * fractionToWithdraw / 1e18;
        uint256 minLUSD = bLUSDLPZap.getMinWithdrawLUSD(withdrawAmount) + 1;
        //console.log(minLUSD, "expectedLUSD");

        vm.startPrank(A);
        bLUSDLUSD3CRVLPToken.approve(address(bLUSDLPZap), withdrawAmount);
        vm.expectRevert();
        bLUSDLPZap.removeLiquidityLUSD(withdrawAmount, minLUSD);
        vm.stopPrank();
    }
}
