pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/ILQTYChickenBondManager.sol";
import "../Interfaces/jar.sol";


contract LQTYChickenBondOperationsScript {
    ILQTYChickenBondManager immutable chickenBondManager;
    IERC20 immutable lqtyToken;
    IERC20 immutable bLQTYToken;
    IJar immutable pickleJar;
    IBancorNetwork immutable public bancorNetwork;
    IERC20 immutable public bntLQTYToken;

    constructor(ILQTYChickenBondManager _chickenBondManager) {
        Address.isContract(address(_chickenBondManager));

        chickenBondManager = _chickenBondManager;
        lqtyToken = _chickenBondManager.lqtyToken();
        bLQTYToken = _chickenBondManager.bLQTYToken();
        pickleJar = _chickenBondManager.pickleJar();
        bancorNetwork = _chickenBondManager.bancorNetwork();
        bntLQTYToken = _chickenBondManager.bntLQTYToken();
    }

    function createBond(uint256 _lqtyAmount) external {
        // Pull LQTY from owner if needed
        uint256 proxyBalance = lqtyToken.balanceOf(address(this));
        if (proxyBalance < _lqtyAmount) {
            lqtyToken.transferFrom(msg.sender, address(this), _lqtyAmount - proxyBalance);
        }

        // Approve LQTY
        lqtyToken.approve(address(chickenBondManager), _lqtyAmount);

        chickenBondManager.createBond(_lqtyAmount);
    }

    function chickenOut(uint256 _bondID) external {
        (uint256 lqtyAmount, ) = chickenBondManager.getBondData(_bondID);
        assert(lqtyAmount > 0);

        // Chicken out
        chickenBondManager.chickenOut(_bondID);

        // send LQTY to owner
        lqtyToken.transfer(msg.sender, lqtyAmount);
    }

    function chickenIn(uint256 _bondID) external {
        uint256 balanceBefore = bLQTYToken.balanceOf(address(this));

        // Chicken in
        chickenBondManager.chickenIn(_bondID);

        uint256 balanceAfter = bLQTYToken.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);

        // send bLQTY to owner
        bLQTYToken.transfer(msg.sender, balanceAfter - balanceBefore);
    }

    function redeem(uint256 _bLQTYToRedeem) external {
        // pull first bLQTY if needed:
        uint256 proxyBalance = bLQTYToken.balanceOf(address(this));
        if (proxyBalance < _bLQTYToRedeem) {
            bLQTYToken.transferFrom(msg.sender, address(this), _bLQTYToRedeem - proxyBalance);
        }

        (uint256 pTokensFromPickleJar, uint256 bnTokensFromBancorPool) = chickenBondManager.redeem(_bLQTYToRedeem);

        // Send native Tokens to the redeemer
        if (pTokensFromPickleJar > 0) {pickleJar.transfer(msg.sender, pTokensFromPickleJar);}
        if (bnTokensFromBancorPool > 0) {bntLQTYToken.transfer(msg.sender, bnTokensFromBancorPool);}
    }

    function redeemAndWithdraw(uint256 _bLQTYToRedeem) external {
        // pull first bLQTY if needed:
        uint256 proxyBalance = bLQTYToken.balanceOf(address(this));
        if (proxyBalance < _bLQTYToRedeem) {
            bLQTYToken.transferFrom(msg.sender, address(this), _bLQTYToRedeem - proxyBalance);
        }

        (uint256 pTokensFromPickleJar, uint256 bnTokensFromBancorPool) = chickenBondManager.redeem(_bLQTYToRedeem);


        // Obtain LQTY from Pickle
        if (pTokensFromPickleJar > 0) {
            // The LQTY delta from Pickle withdrawal is the amount to send to the redeemer
            uint256 lqtyBalanceBefore = lqtyToken.balanceOf(address(this));
            pickleJar.withdraw(pTokensFromPickleJar);

            uint256 lqtyBalanceDelta = lqtyToken.balanceOf(address(this)) - lqtyBalanceBefore;

            // Send the LQTY to the redeemer
            lqtyToken.transfer(msg.sender, lqtyBalanceDelta);
        }

        // Start Bancor withdrawal process
        if (bnTokensFromBancorPool > 0) { bancorNetwork.initWithdrawal(address(lqtyToken), bnTokensFromBancorPool); }
    }
}
