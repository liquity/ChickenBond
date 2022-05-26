// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "../../../lib/forge-std/src/stdlib.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./Accounts.sol";
import "../../SLUSDToken.sol";
import "../../BondNFT.sol";
import "./ChickenBondManagerWrap.sol";
import "../../Interfaces/IYearnVault.sol";
import "../../Interfaces/ICurvePool.sol";
import "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "../../LPRewards/Interfaces/IUnipool.sol";
import "../../LPRewards/Unipool.sol";


contract BaseTest is DSTest, stdCheats {
    Accounts accounts;

    // Core ChickenBond contracts
    ChickenBondManagerWrap chickenBondManager;
    BondNFT bondNFT;
    SLUSDToken sLUSDToken;

    // Integrations
    IERC20 lusdToken;
    IERC20 _3crvToken;
    ICurvePool curvePool;
    IYearnVault yearnLUSDVault;
    IYearnVault yearnCurveVault;
    IYearnRegistry yearnRegistry;
    IUnipool sLUSDLPRewardsStaking;

    address yearnGovernanceAddress;
    address liquitySPAddress;

    uint256 CHICKEN_IN_AMM_TAX = 1e16; // 1%

    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    // Seconds in one month as an 18 digit fixed-point number
    uint256 constant INITIAL_ACCRUAL_PARAMETER = 30 days * 1e18;
    uint256 constant MINIMUM_ACCRUAL_PARAMETER = INITIAL_ACCRUAL_PARAMETER / 1000;
    uint256 constant ACCRUAL_ADJUSTMENT_RATE = 1e16; // 1% (0.01)
    uint256 constant TARGET_AVERAGE_AGE_SECONDS = 30 days;
    uint256 constant ACCRUAL_ADJUSTMENT_PERIOD_SECONDS = 1 days;

    Vm vm = Vm(CHEATCODE_ADDRESS);

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

    // Coerce x into range [a, b] (inclusive) by modulo division.
    // Preserves x if it's already within range.
    function coerce(uint256 x, uint256 a, uint256 b) public pure returns (uint256) {
        (uint256 min, uint256 max) = a < b ? (a, b) : (b, a);

        if (min <= x && x <= max) {
            return x;
        }

        // The only case in which this would overflow is min = 0, max = 2**256-1;
        // however in that case we would have returned by now (see above).
        uint256 modulus = max - min + 1;

        if (x >= min) {
            return min + (x - min) % modulus;
        } else {
            // x < min, therefore x < max, also
            return max - (max - x) % modulus;
        }
    }

    // --- Helpers ---

    // Create a bond for `_user` using `_bondAmount` amount of LUSD, then return the bond's ID.
    function createBondForUser(address _user, uint256 _bondAmount) public returns (uint256) {
        vm.startPrank(_user);
        lusdToken.approve(address(chickenBondManager), _bondAmount);
        chickenBondManager.createBond(_bondAmount);
        vm.stopPrank();

        // bond ID
        return bondNFT.totalMinted();
    }

    function chickenInForUser(address _user, uint256 _bondID) public {
        vm.startPrank(_user);
        chickenBondManager.chickenIn(_bondID);
        vm.stopPrank();
    }

    function depositLUSDToCurveForUser(address _user, uint256 _lusdDeposit) public {
        tip(address(lusdToken), _user, _lusdDeposit);
        assertGe(lusdToken.balanceOf(_user), _lusdDeposit);
        vm.startPrank(_user);
        lusdToken.approve(address(curvePool), _lusdDeposit);
        curvePool.add_liquidity([_lusdDeposit, 0], 0);
        vm.stopPrank();
    }

    function makeCurveSpotPriceBelow1(uint256 _lusdDeposit) public {
        uint256 curveLUSDSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        if (curveLUSDSpotPrice < 1e18) {return;}

        // C makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, _lusdDeposit); // C deposits 200m LUSD
        curveLUSDSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
         require(curveLUSDSpotPrice < 1e18, "test helper: deposit insufficient to makeCurveSpotPriceBelow1");
    }

    function makeCurveSpotPriceAbove1(uint256 _3crvDeposit) public {
        uint256 curveLUSDSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        console.log(curveLUSDSpotPrice, "curveLUSDSpotPrice test helper before");
        if (curveLUSDSpotPrice > 1e18) {return;}

        // C makes large 3CRV deposit to Curve, moving Curve spot price above 1.0
        tip(address(_3crvToken), C, _3crvDeposit);
        assertGe(_3crvToken.balanceOf(C), _3crvDeposit);
        vm.startPrank(C);
        _3crvToken.approve(address(curvePool), _3crvDeposit);
        curvePool.add_liquidity([0, _3crvDeposit], 0);
        vm.stopPrank();
       
        curveLUSDSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        console.log(curveLUSDSpotPrice, "curveLUSDSpotPrice test helper after");

        require(curveLUSDSpotPrice > 1e18, "test helper: deposit insufficient to makeCurveSpotPriceAbove1");
    }

    function shiftFractionFromSPToCurve(uint256 _divisor) public returns (uint256) {
        // Put some  LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getOwnedLUSDInSP() / _divisor; // shift fraction of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        return lusdToShift;
    }

    function _getTaxForAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * chickenBondManager.CHICKEN_IN_AMM_TAX() / 1e18;
    }

    function _getTaxedAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * (1e18 - chickenBondManager.CHICKEN_IN_AMM_TAX()) / 1e18;
    }
    
    function diffOrZero(uint256 x, uint256 y) public pure returns (uint256) {
        return x > y ? x - y : 0;
    }

    function logCBMBuckets(string memory _logHeadingText) public view {
        console.log(_logHeadingText);
        console.log(chickenBondManager.totalPendingLUSD(), "totalPendingLUSD");
        console.log(chickenBondManager.getAcquiredLUSDInSP(), "Acquired LUSD in Yearn");
        console.log(chickenBondManager.getAcquiredLUSDInCurve(), "Acquired LUSD in Curve");
        console.log(chickenBondManager.getPermanentLUSDInSP(), "Permanent LUSD in Yearn");
        console.log(chickenBondManager.getPermanentLUSDInCurve(), "Permanent LUSD in Curve");
        console.log(chickenBondManager.getOwnedLUSDInSP(), "Owned LUSD in SP (Ac. + Perm.)");
        console.log(chickenBondManager.getOwnedLUSDInCurve(), "Owned LUSD in Curve (Ac. + Perm.)");
    }
}
