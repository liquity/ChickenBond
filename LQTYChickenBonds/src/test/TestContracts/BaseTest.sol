// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./Accounts.sol";
import "../../BLQTYToken.sol";
import "../../BondNFT.sol";
import "./LQTYChickenBondManagerWrap.sol";
import "../../Interfaces/ICurveLiquidityGaugeV4.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract BaseTest is Test {
    Accounts accounts;

    // Core ChickenBond contracts
    LQTYChickenBondManagerWrap chickenBondManager;
    BondNFT bondNFT;
    BLQTYToken bLQTYToken;

    // Integrations
    IERC20 lqtyToken;
    IJar pickleJar;
    IBancorNetworkInfo bancorNetworkInfo;
    IBancorNetwork bancorNetwork;
    ICurveLiquidityGaugeV4 curveLiquidityGauge;

    uint256 CHICKEN_IN_AMM_FEE = 1e16; // 1%

    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    // Seconds in one month as an 18 digit fixed-point number
    uint256 constant INITIAL_ACCRUAL_PARAMETER = 30 days * 1e18;
    uint256 constant MINIMUM_ACCRUAL_PARAMETER = INITIAL_ACCRUAL_PARAMETER / 1000;
    uint256 constant ACCRUAL_ADJUSTMENT_RATE = 1e16; // 1% (0.01)
    uint256 constant TARGET_AVERAGE_AGE_SECONDS = 30 days;
    uint256 constant ACCRUAL_ADJUSTMENT_PERIOD_SECONDS = 1 days;

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

    // Create a bond for `_user` using `_bondAmount` amount of LQTY, then return the bond's ID.
    function createBondForUser(address _user, uint256 _bondAmount) public returns (uint256) {
        vm.startPrank(_user);
        lqtyToken.approve(address(chickenBondManager), _bondAmount);
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
        console.log(chickenBondManager.getPendingLQTY(), "pendingLQTY");
        console.log(chickenBondManager.getAcquiredLQTY(), "Acquired LQTY");
        console.log(chickenBondManager.getPermanentLQTY(), "Permanent LQTY");
        console.log(chickenBondManager.getOwnedLQTY(), "Owned LQTY (Ac. + Perm.)");
    }

    function logState(string memory _logHeadingText) public view {
        console.log("");
        logCBMBuckets(_logHeadingText);
        console.log(chickenBondManager.calcSystemBackingRatio(), "Backing ratio");
        console.log(bLQTYToken.totalSupply(), "bLQTY total supply");
        console.log(lqtyToken.balanceOf(address(curveLiquidityGauge)), "balance of AMM rewards contract");
        console.log("");
    }
}
