// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./Accounts.sol";
import "../../BLUSDToken.sol";
import "../../BondNFT.sol";
import "./ChickenBondManagerWrap.sol";
import "../../Interfaces/IYearnVault.sol";
import "../../Interfaces/IBAMM.sol";
import "../../Interfaces/ICurvePool.sol";
import "../../Interfaces/ICurveLiquidityGaugeV5.sol";
import "./Interfaces/IERC20Permit.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./TestUtils.sol";

import "forge-std/console.sol";


contract BaseTest is Test {
    Accounts accounts;

    // Core ChickenBond contracts
    ChickenBondManagerWrap chickenBondManager;
    BondNFT bondNFT;
    BLUSDToken bLUSDToken;

    // Integrations
    IERC20Permit lusdToken;
    IERC20 _3crvToken;
    ICurvePool curvePool;
    ICurvePool curveBasePool;
    IBAMM bammSPVault;
    IYearnVault yearnCurveVault;
    IYearnRegistry yearnRegistry;
    ICurveLiquidityGaugeV5 curveLiquidityGauge;

    address yearnGovernanceAddress;
    address liquitySPAddress;

    uint256 CHICKEN_IN_AMM_FEE = 1e16; // 1%
    uint256 MIN_BLUSD_SUPPLY = 1e18;
    uint256 MIN_BOND_AMOUNT = 100e18;

    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    // Seconds in one month as an 18 digit fixed-point number
    uint256 constant INITIAL_ACCRUAL_PARAMETER = 30 days * 1e18;
    uint256 constant MINIMUM_ACCRUAL_PARAMETER = INITIAL_ACCRUAL_PARAMETER / 1000;
    uint256 constant ACCRUAL_ADJUSTMENT_RATE = 1e16; // 1% (0.01)
    uint256 constant TARGET_AVERAGE_AGE_SECONDS = 30 days;
    uint256 constant ACCRUAL_ADJUSTMENT_PERIOD_SECONDS = 1 days;
    uint256 constant BOND_NFT_TRANSFER_LOCKOUT_PERIOD_SECONDS = 1 days;

    uint256 SHIFTER_DELAY;
    uint256 SHIFTER_WINDOW;

    uint256 MAX_UINT256 = type(uint256).max;
    uint256 constant SECONDS_IN_ONE_MONTH = 2592000;

    address[] accountsList;
    address public A;
    address public B;
    address public C;
    address public D;

    function createAccounts() public {
        address[10] memory tempAccounts;
        for (uint256 i = 0; i < accounts.getAccountsCount(); i++) {
            tempAccounts[i] = vm.addr(uint256(accounts.accountsPks(i)));
        }

        accountsList = tempAccounts;
    }

    function assertApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin) public {
        assertApproximatelyEqual(_x, _y, _margin, "");
    }

    function assertApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin, string memory _reason) public {
        uint256 diff = abs(_x, _y);
        assertLe(diff, _margin, _reason);
    }

    function assertNotApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin) public {
        assertNotApproximatelyEqual(_x, _y, _margin, "");
    }

    function assertNotApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin, string memory _reason) public {
        uint256 diff = abs(_x, _y);
        assertGt(diff, _margin, _reason);
    }

    function assertGeAndWithinRange(uint256 _x, uint256 _y, uint _margin) public {
        assertGe(_x, _y);
        assertLe(_x - _y, _margin);
    }

    function assertRelativeError(uint256 _x, uint256 _y, uint _margin) public {
        assertRelativeError(_x, _y, _margin, "");
    }

    function assertRelativeError(uint256 _x, uint256 _y, uint _margin, string memory _reason) public {
        assertLt(abs(_x, _y) * 1e18 / _y, _margin, _reason);
    }

    function abs(uint256 x, uint256 y) public pure returns (uint256) {
        return x > y ? x - y : y - x;
    }

    // --- Helpers ---

    // Create a bond for `_user` using `_bondAmount` amount of LUSD, then return the bond's ID.
    function createBondForUser(address _user, uint256 _bondAmount) public returns (uint256) {
        vm.startPrank(_user);
        lusdToken.approve(address(chickenBondManager), _bondAmount);
        chickenBondManager.createBond(_bondAmount);
        vm.stopPrank();

        // bond ID
        return bondNFT.totalSupply();
    }

    function chickenInForUser(address _user, uint256 _bondID) public {
        vm.startPrank(_user);
        chickenBondManager.chickenIn(_bondID);
        vm.stopPrank();
    }

    function chickenOutForUser(address _user, uint256 _bondID, uint256 _minLUSD) public {
        vm.startPrank(_user);
        chickenBondManager.chickenOut(_bondID, _minLUSD);
        vm.stopPrank();
    }

    function chickenOutForUser(address _user, uint256 _bondID) public {
        chickenOutForUser(_user, _bondID, 0);
    }

    function depositLUSDToCurveForUser(address _user, uint256 _lusdDeposit) public {
        deal(address(lusdToken), _user, _lusdDeposit);
        assertGe(lusdToken.balanceOf(_user), _lusdDeposit);
        vm.startPrank(_user);
        lusdToken.approve(address(curvePool), _lusdDeposit);
        curvePool.add_liquidity([_lusdDeposit, 0], 0);
        vm.stopPrank();
    }

    function _startShiftCountdownAndWarpInsideWindow() internal {
        // Start countdown and fast-forward to inside shifting window
        chickenBondManager.startShifterCountdown();
        uint256 countdownStartTime = chickenBondManager.lastShifterCountdownStartTime();
        vm.warp(countdownStartTime + SHIFTER_DELAY + SHIFTER_WINDOW - 1);
    }

    function _getLUSD3CRVExchangeRate() internal view returns (uint256) {
        return curvePool.get_dy(0, 1, curveBasePool.get_virtual_price());
    }

    function _get3CRVLUSDExchangeRate() internal view returns (uint256) {
        return curvePool.get_dy(1, 0, 1e36 / curveBasePool.get_virtual_price());
    }

    function makeCurveSpotPriceBelow1(uint256 _lusdDeposit) public {
        uint256 withdrawalThreshold = chickenBondManager.curveWithdrawal3CRVLUSDExchangeRateThreshold();
        uint256 _3crvLUSDExchangeRate = _get3CRVLUSDExchangeRate();
        if (_3crvLUSDExchangeRate > withdrawalThreshold) {return;}

        // C makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, _lusdDeposit);

        _3crvLUSDExchangeRate = _get3CRVLUSDExchangeRate();
        //console.log(_3crvLUSDExchangeRate, "_3crvLUSDExchangeRate");
        //console.log(withdrawalThreshold, "withdrawalThreshold");
        require(_3crvLUSDExchangeRate > withdrawalThreshold, "test helper: deposit insufficient to makeCurveSpotPriceBelow1");
    }

    function makeCurveSpotPriceAbove1(uint256 _3crvDeposit) public {
        uint256 depositThreshold = chickenBondManager.curveDepositLUSD3CRVExchangeRateThreshold();
        uint256 lusd3CRVExchangeRate = _getLUSD3CRVExchangeRate();
        if (lusd3CRVExchangeRate > depositThreshold) {return;}

        // C makes large 3CRV deposit to Curve, moving Curve spot price above 1.0
        deal(address(_3crvToken), C, _3crvDeposit);
        assertGe(_3crvToken.balanceOf(C), _3crvDeposit);
        vm.startPrank(C);
        _3crvToken.approve(address(curvePool), _3crvDeposit);
        curvePool.add_liquidity([0, _3crvDeposit], 0);
        vm.stopPrank();

        lusd3CRVExchangeRate = _getLUSD3CRVExchangeRate();
        require(lusd3CRVExchangeRate > depositThreshold, "test helper: deposit insufficient to makeCurveSpotPriceAbove1");
    }

    function shiftFractionFromSPToCurve(uint256 _divisor) public returns (uint256) {
        // Put some  LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0, "Already some acquired LUSD in Curve");
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / _divisor; // shift fraction of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0, "No acquired LUSD in Curve");

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGe(curveSpotPrice, 1e18, "Curve spot price < 1");
        return lusdToShift;
    }

    function _getChickenInFeeForAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * chickenBondManager.CHICKEN_IN_AMM_FEE() / 1e18;
    }

    function _getAmountMinusChickenInFee(uint256 _amount) internal view returns (uint256) {
        return _amount * (1e18 - chickenBondManager.CHICKEN_IN_AMM_FEE()) / 1e18;
    }

    function diffOrZero(uint256 x, uint256 y) public pure returns (uint256) {
        return x > y ? x - y : 0;
    }

    function logCBMBuckets(string memory _logHeadingText) public view {
        console.log(_logHeadingText);
        console.log(chickenBondManager.getPendingLUSD(), "totalPendingLUSD");
        console.log(chickenBondManager.getAcquiredLUSDInSP(), "Acquired LUSD in SP");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "Acquired LUSD in Curve");
        console.log(chickenBondManager.getPermanentLUSD(), "Permanent LUSD");
        console.log(chickenBondManager.getOwnedLUSDInSP(), "Owned LUSD in SP (Ac. + Perm.)");
        console.log(chickenBondManager.getOwnedLUSDInCurve(), "Owned LUSD in Curve (Ac. + Perm.)");
    }

    function logState(string memory _logHeadingText) public view {
        console.log("");
        logCBMBuckets(_logHeadingText);
        console.log(chickenBondManager.calcSystemBackingRatio(), "Backing ratio");
        console.log(bLUSDToken.totalSupply(), "bLUSD total supply");
        console.log(lusdToken.balanceOf(address(curveLiquidityGauge)), "balance of AMM rewards contract");
        (uint256 bammSPVaultLUSDValue, uint256 lusdInBAMMSPVault, uint256 ethLUSDValueInBAMMSPVault) = bammSPVault.getLUSDValue();
        console.log(bammSPVaultLUSDValue, "LUSD value in B.Protocol");
        console.log(lusdInBAMMSPVault, "LUSD balance in B.Protocol");
        console.log(ethLUSDValueInBAMMSPVault, "LUSD value in ETH in B.Protocol");
        console.log(yearnCurveVault.balanceOf(address(chickenBondManager)),"Curve Y tokens in CBM");
        console.log("");
    }
}
