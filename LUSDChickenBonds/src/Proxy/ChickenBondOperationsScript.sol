pragma solidity ^0.8.10;

//import "../utils/console.sol";
import "../Interfaces/IChickenBondManager.sol";
import "../Interfaces/ICurvePool.sol";
import "../Interfaces/IYearnVault.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract ChickenBondOperationsScript {
    IChickenBondManager immutable chickenBondManager;
    IERC20 immutable lusdToken;
    IERC20 immutable bLUSDToken;
    ICurvePool immutable curvePool;
    IYearnVault immutable public yearnSPVault;
    IYearnVault immutable public yearnCurveVault;

    int128 immutable INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL;// = 0;

    constructor(IChickenBondManager _chickenBondManager) {
        Address.isContract(address(_chickenBondManager));

        chickenBondManager = _chickenBondManager;
        lusdToken = _chickenBondManager.lusdToken();
        bLUSDToken = _chickenBondManager.bLUSDToken();
        curvePool = _chickenBondManager.curvePool();
        yearnSPVault = _chickenBondManager.yearnSPVault();
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

    function chickenOut(uint256 _bondID) external {
        (uint256 lusdAmount, ) = chickenBondManager.getIdToBondData(_bondID);
        assert(lusdAmount > 0);

        // Chicken out
        chickenBondManager.chickenOut(_bondID);

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

    function redeem(uint256 _bLUSDToRedeem) external {
        // pull first bLUSD if needed:
        uint256 proxyBalance = bLUSDToken.balanceOf(address(this));
        if (proxyBalance < _bLUSDToRedeem) {
            bLUSDToken.transferFrom(msg.sender, address(this), _bLUSDToRedeem - proxyBalance);
        }

        (uint256 yTokensFromSPVault, uint256 yTokensFromCurveVault, ) = chickenBondManager.redeem(_bLUSDToRedeem);

        // Send yTokens to the redeemer
        if (yTokensFromSPVault > 0) {yearnSPVault.transfer(msg.sender, yTokensFromSPVault);}
        if (yTokensFromCurveVault > 0) {yearnCurveVault.transfer(msg.sender, yTokensFromCurveVault);}
    }

    function redeemAndWithdraw(uint256 _bLUSDToRedeem) external {
        // pull first bLUSD if needed:
        uint256 proxyBalance = bLUSDToken.balanceOf(address(this));
        if (proxyBalance < _bLUSDToRedeem) {
            bLUSDToken.transferFrom(msg.sender, address(this), _bLUSDToRedeem - proxyBalance);
        }

        (uint256 yTokensFromSPVault, uint256 yTokensFromCurveVault, ) = chickenBondManager.redeem(_bLUSDToRedeem);

        // The LUSD deltas from SP/Curve withdrawals are the amounts to send to the redeemer
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));

        // Withdraw obtained yTokens from both vaults
        if (yTokensFromSPVault > 0) {yearnSPVault.withdraw(yTokensFromSPVault);} // obtain LUSD from Yearn
        if (yTokensFromCurveVault > 0) {yearnCurveVault.withdraw(yTokensFromCurveVault);} // obtain LUSD3CRV from Yearn

        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // obtain LUSD from Curve
        if (LUSD3CRVBalanceDelta > 0) {
            curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        }

        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
        require(lusdBalanceDelta > 0, "Obtained LUSD amount must be > 0");

        // Send the LUSD to the redeemer
        lusdToken.transfer(msg.sender, lusdBalanceDelta);
    }
}
