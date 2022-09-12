// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../Interfaces/IChickenBondManager.sol";
import "../Interfaces/ICurvePool.sol";
import "../Interfaces/IYearnVault.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

//import "forge-std/console.sol";


contract ChickenBondOperationsScript {
    IChickenBondManager immutable chickenBondManager;
    IERC20 immutable lusdToken;
    IERC20 immutable bLUSDToken;
    ICurvePool immutable curvePool;
    IYearnVault immutable public yearnCurveVault;

    int128 immutable INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL;// = 0;

    constructor(IChickenBondManager _chickenBondManager) {
        require(Address.isContract(address(_chickenBondManager)), "ChickenBondManager is not a contract");

        chickenBondManager = _chickenBondManager;
        lusdToken = _chickenBondManager.lusdToken();
        bLUSDToken = _chickenBondManager.bLUSDToken();
        curvePool = _chickenBondManager.curvePool();
        yearnCurveVault = _chickenBondManager.yearnCurveVault();

        INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = _chickenBondManager.INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL();
    }

    function createBond(uint256 _lusdAmount) external {
        // Pull LUSD from owner if needed
        uint256 proxyBalance = lusdToken.balanceOf(address(this));
        if (proxyBalance < _lusdAmount) {
            lusdToken.transferFrom(msg.sender, address(this), _lusdAmount - proxyBalance);
        }

        // Approve LUSD
        lusdToken.approve(address(chickenBondManager), _lusdAmount);

        chickenBondManager.createBond(_lusdAmount);
    }

    function chickenOut(uint256 _bondID, uint256 _minLUSD) external {
        (uint256 lusdAmount,,,,) = chickenBondManager.getBondData(_bondID);
        assert(lusdAmount > 0);

        // Chicken out
        chickenBondManager.chickenOut(_bondID, _minLUSD);

        // send LUSD to owner
        lusdToken.transfer(msg.sender, lusdAmount);
    }

    function chickenIn(uint256 _bondID) external {
        uint256 balanceBefore = bLUSDToken.balanceOf(address(this));

        // Chicken in
        chickenBondManager.chickenIn(_bondID);

        uint256 balanceAfter = bLUSDToken.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);

        // send bLUSD to owner
        bLUSDToken.transfer(msg.sender, balanceAfter - balanceBefore);
    }

    function redeem(uint256 _bLUSDToRedeem, uint256 _minLUSDFromBAMMSPVault) external {
        // pull first bLUSD if needed:
        uint256 proxyBalance = bLUSDToken.balanceOf(address(this));
        if (proxyBalance < _bLUSDToRedeem) {
            bLUSDToken.transferFrom(msg.sender, address(this), _bLUSDToRedeem - proxyBalance);
        }

        (uint256 lusdFromBAMMSPVault,uint256 yTokensFromCurveVault) = chickenBondManager.redeem(_bLUSDToRedeem, _minLUSDFromBAMMSPVault);

        // Send LUSD to the redeemer
        if (lusdFromBAMMSPVault > 0) {lusdToken.transfer(msg.sender, lusdFromBAMMSPVault);}

        // Send yTokens to the redeemer
        if (yTokensFromCurveVault > 0) {yearnCurveVault.transfer(msg.sender, yTokensFromCurveVault);}
    }

    function redeemAndWithdraw(uint256 _bLUSDToRedeem, uint256 _minLUSDFromBAMMSPVault) external {
        // pull first bLUSD if needed:
        uint256 proxyBalance = bLUSDToken.balanceOf(address(this));
        if (proxyBalance < _bLUSDToRedeem) {
            bLUSDToken.transferFrom(msg.sender, address(this), _bLUSDToRedeem - proxyBalance);
        }

        (uint256 lusdFromBAMMSPVault,uint256 yTokensFromCurveVault) = chickenBondManager.redeem(_bLUSDToRedeem, _minLUSDFromBAMMSPVault);

        // The LUSD deltas from SP/Curve withdrawals are the amounts to send to the redeemer
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));

        // Withdraw obtained yTokens from both vaults
        if (yTokensFromCurveVault > 0) {yearnCurveVault.withdraw(yTokensFromCurveVault);} // obtain LUSD3CRV from Yearn

        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // obtain LUSD from Curve
        if (LUSD3CRVBalanceDelta > 0) {
            curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        }

        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
        uint256 totalReceivedLUSD = lusdFromBAMMSPVault + lusdBalanceDelta;
        require(totalReceivedLUSD > 0, "Obtained LUSD amount must be > 0");

        // Send the LUSD to the redeemer
        lusdToken.transfer(msg.sender, totalReceivedLUSD);
    }
}
