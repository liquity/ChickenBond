pragma solidity ^0.8.10;

import "../Interfaces/IChickenBondManager.sol";
import "../Interfaces/ICurvePool.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract ChickenBondOperationsScript {
    IChickenBondManager immutable chickenBondManager;
    IERC20 immutable lusdToken;
    IERC20 immutable sLUSDToken;
    ICurvePool immutable curvePool;

    int128 immutable INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL;// = 0;

    constructor(IChickenBondManager _chickenBondManager, IERC20 _lusdToken, IERC20 _sLUSDToken, ICurvePool _curvePool) {
        Address.isContract(address(_chickenBondManager));
        Address.isContract(address(_lusdToken));
        Address.isContract(address(_sLUSDToken));
        Address.isContract(address(_curvePool));

        chickenBondManager = _chickenBondManager;
        lusdToken = _lusdToken;
        sLUSDToken = _sLUSDToken;
        curvePool = _curvePool;

        INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = chickenBondManager.getIndexOfLusdTokenInCurvePool();
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

    function chickenOut(uint256 _bondID) external {
        (uint256 lusdAmount, ) = chickenBondManager.getIdToBondData(_bondID);
        assert(lusdAmount > 0);

        // Chicken out
        chickenBondManager.chickenOut(_bondID);

        // send LUSD to owner
        lusdToken.transfer(msg.sender, lusdAmount);
    }

    function chickenIn(uint256 _bondID) external {
        uint256 balanceBefore = sLUSDToken.balanceOf(address(this));

        // Chicken in
        chickenBondManager.chickenIn(_bondID);

        uint256 balanceAfter = sLUSDToken.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);

        // send sLUSD to owner
        sLUSDToken.transfer(msg.sender, balanceAfter - balanceBefore);
    }

    function redeem(uint256 _sLUSDToRedeem) external {
        (, uint256 LUSD3CRVAmount) = chickenBondManager.redeem(_sLUSDToRedeem);

        // obtain LUSD from Curve
        if (LUSD3CRVAmount > 0) {
            curvePool.remove_liquidity_one_coin(LUSD3CRVAmount, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        }
    }
}
