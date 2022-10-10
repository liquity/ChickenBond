pragma solidity ^0.8.11;

import "../BLUSDLPZap.sol";
import "./TestContracts/BaseTest.sol";


contract BLUSDLPZapTest is BaseTest {
    BLUSDLPZap bLUSDLPZap;
    IERC20 bLUSDLUSD3CRVLPToken;
    ICurveLiquidityGaugeV5 bLUSDGauge;

    function setUp() public {
        bLUSDLPZap = new BLUSDLPZap();
        lusdToken = IERC20Permit(address(bLUSDLPZap.lusdToken()));
        bLUSDToken = BLUSDToken(address(bLUSDLPZap.bLUSDToken()));
        _3crvToken = IERC20(address(bLUSDLPZap.lusd3CRVPool()));
        bLUSDLUSD3CRVLPToken = bLUSDLPZap.bLUSDLUSD3CRVLPToken();
        bLUSDGauge = bLUSDLPZap.bLUSDGauge();

        accounts = new Accounts();
        createAccounts();
        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);
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

    function _addLiquidity(uint256 bLUSDAmount, uint256 lusdAmount, uint256 minLPAmount) internal {
        vm.startPrank(A);
        _dealAndApprove(bLUSDAmount, lusdAmount);
        // add liquidity
        bLUSDLPZap.addLiquidity(bLUSDAmount, lusdAmount, minLPAmount);
        vm.stopPrank();
    }

    function testAddLiquidityGetsLPTokensNoMin() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        uint256 initialLUSD3CRVBalance = _3crvToken.balanceOf(A);
        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);
        _addLiquidity(bLUSDAmount, lusdAmount, 0);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        assertEq(_3crvToken.balanceOf(A) - initialLUSD3CRVBalance, 0, "User should not receive 3pool LP tokens");
        assertGt(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, 0, "User should receive LP tokens");
    }

    function testAddLiquidityGetsMinLPTokens() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 minLPAmount = 1145e18;

        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);
        _addLiquidity(bLUSDAmount, lusdAmount, minLPAmount);

        console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        assertGt(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, minLPAmount, "Not enough LP tokens received");
    }

    function testAddLiquidityFailsIfNotMinLPTokens() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;
        uint256 minLPAmount = 1146e18;

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
        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);
        uint256 minLPAmount = bLUSDLPZap.getMinLPTokens(bLUSDAmount2, 0);
        //console.log(minLPAmount, "minLPAmount");
        _addLiquidity(bLUSDAmount2, 0, minLPAmount);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A)  - initialbLUSDLUSD3CRVLPTokenBalance, "bLUSDLUSD3CRVLPToken received");
        assertGt(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, 0, "User should receive LP tokens");
    }

    function testAddLiquiditySingleSidedLUSD() public {
        uint256 bLUSDAmount = 1000e18;
        uint256 lusdAmount = 1300e18;

        // Initial liquidity must be dual sided
        _addLiquidity(bLUSDAmount, lusdAmount, 0);

        uint256 lusdAmount2 = lusdAmount / 10;
        uint256 initialbLUSDLUSD3CRVLPTokenBalance = bLUSDLUSD3CRVLPToken.balanceOf(A);
        uint256 minLPAmount = bLUSDLPZap.getMinLPTokens(0, lusdAmount2) * 9995 / 10000; // TODO: there’s some rounding issue here with calc_token_amount?
        //console.log(minLPAmount, "minLPAmount");
        _addLiquidity(0, lusdAmount2, minLPAmount);

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A)  - initialbLUSDLUSD3CRVLPTokenBalance, "bLUSDLUSD3CRVLPToken received");
        assertGt(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, 0, "User should receive LP tokens");
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
        // add liquidity and stake
        bLUSDLPZap.addLiquidityAndStake(bLUSDAmount, lusdAmount, 0);
        vm.stopPrank();

        //console.log(bLUSDLUSD3CRVLPToken.balanceOf(A), "bLUSDLUSD3CRVLPToken.balanceOf(A)");
        //console.log(bLUSDGauge.balanceOf(A), "bLUSDGauge.balanceOf(A)");
        assertEq(bLUSDLUSD3CRVLPToken.balanceOf(A) - initialbLUSDLUSD3CRVLPTokenBalance, 0, "User should not receive LP tokens");
        assertGt(bLUSDGauge.balanceOf(A) - initialbLUSDGaugeBalance, 1145, "User should receive LP tokens");
    }
}
