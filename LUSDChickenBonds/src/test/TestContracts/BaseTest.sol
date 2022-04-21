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

    address yearnGovernanceAddress;

    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    uint256 constant SECONDS_IN_ONE_DAY = 24 * 60 * 60;
    uint256 constant SECONDS_IN_ONE_MONTH = 30 * SECONDS_IN_ONE_DAY;

    // Seconds in one month as an 18 digit fixed-point number
    uint256 constant INITIAL_ACCRUAL_PARAMETER = SECONDS_IN_ONE_MONTH * 1e18;
    uint256 constant MINIMUM_ACCRUAL_PARAMETER = INITIAL_ACCRUAL_PARAMETER / 1000;
    uint256 constant ACCRUAL_ADJUSTMENT_RATE = 1e16; // 1% (0.01)

    Vm vm = Vm(CHEATCODE_ADDRESS);

    uint256 MAX_UINT256 = type(uint256).max;

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
        uint256 diff = abs(_x, _y);
        assertLe(diff, _margin);
    }

    function assertNotApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin) public {
        uint256 diff = abs(_x, _y);
        assertGt(diff, _margin);
    }

    function assertGeAndWithinRange(uint256 _x, uint256 _y, uint _margin) public {
        assertGe(_x, _y);
        assertLe(_x - _y, _margin);
    }

    function abs(uint256 x, uint256 y) public pure returns (uint256) {
        return x > y ? x - y : y - x;
    }
}
