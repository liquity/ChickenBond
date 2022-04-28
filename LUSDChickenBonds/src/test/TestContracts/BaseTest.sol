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
import "../Dependencies/Uniswap/interfaces/IUniswapV2Factory.sol";


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
    IUniswapV2Factory uniswapV2Factory;

    address yearnGovernanceAddress;

    uint256 CHICKEN_IN_AMM_TAX = 1e16; // 1%

    address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

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

    // --- Helpers ---

    function createBondForUser(address _user, uint256 _bondAmount) public returns (uint256) {
        vm.startPrank(_user);
        lusdToken.approve(address(chickenBondManager), _bondAmount);
        chickenBondManager.createBond(_bondAmount);
        vm.stopPrank();

        // bond ID
        return bondNFT.totalMinted();
    }

    function depositLUSDToCurveForUser(address _user, uint256 _lusdDeposit) public {
        tip(address(lusdToken), _user, _lusdDeposit);
        assertGe(lusdToken.balanceOf(_user), _lusdDeposit);
        vm.startPrank(_user);
        lusdToken.approve(address(curvePool), _lusdDeposit);
        curvePool.add_liquidity([_lusdDeposit, 0], 0);
        vm.stopPrank();
    }

    function _getTaxForAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * chickenBondManager.CHICKEN_IN_AMM_TAX() / 1e18;
    }

    function _getTaxedAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * (1e18 - chickenBondManager.CHICKEN_IN_AMM_TAX()) / 1e18;
    }

    function _calcAccruedSLUSD(uint256 _startTime, uint256 _lusdAmount, uint256 _backingRatio) internal view returns (uint256) {
        uint256 bondSLUSDCap = _lusdAmount * 1e18 / _backingRatio;

        uint256 bondDuration = (block.timestamp - _startTime);

        // TODO: replace with final sLUSD accrual formula. */
        return bondSLUSDCap * bondDuration / (bondDuration + SECONDS_IN_ONE_MONTH);
    }
}
