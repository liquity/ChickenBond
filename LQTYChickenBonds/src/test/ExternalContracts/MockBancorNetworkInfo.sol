// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBancorNetwork } from "../../Interfaces/IBancorNetwork.sol";
import { IBancorNetworkInfo, TradingLiquidity, WithdrawalAmounts } from "../../Interfaces/IBancorNetworkInfo.sol";
import "./MockBancorNetwork.sol";

contract MockBancorNetworkInfo is IBancorNetworkInfo {
    IBancorNetwork immutable public network;
    IERC20 immutable public lqtyToken;

    constructor(IBancorNetwork _bancorNetwork, IERC20 _lqtyToken) {
        network = _bancorNetwork;
        lqtyToken = _lqtyToken;
    }

    /**
     * @dev returns the BNT contract
     */
    function bnt() external view returns (IERC20) {}

    /**
     * @dev returns the BNT governance contract
     */
    function bntGovernance() external view returns (address) {}

    /**
     * @dev returns the vBNT contract
     */
    function vbnt() external view returns (IERC20) {}

    /**
     * @dev returns the vBNT governance contract
     */
    function vbntGovernance() external view returns (address) {}

    /**
     * @dev returns the network settings contract
     */
    function networkSettings() external view returns (address) {}

    /**
     * @dev returns the master vault contract
     */
    function masterVault() external view returns (address) {}

    /**
     * @dev returns the address of the external protection vault
     */
    function externalProtectionVault() external view returns (address) {}

    /**
     * @dev returns the address of the external rewards vault
     */
    function externalRewardsVault() external view returns (address) {}

    /**
     * @dev returns the BNT pool contract
     */
    function bntPool() external view returns (address) {}

    /**
     * @dev returns the pool token contract for a given pool
     */
    function poolToken(address /*pool*/) external view returns (address) {
        return address(MockBancorNetwork(address(network)).bntLQTY());
    }

    /**
     * @dev returns the staked balance in a given pool
     */
    function stakedBalance(address pool) external view returns (uint256) {}

    /**
     * @dev returns the trading liquidity in a given pool
     */
    function tradingLiquidity(address pool) external view returns (TradingLiquidity memory) {}

    /**
     * @dev returns the trading fee (in units of PPM)
     */
    function tradingFeePPM(address pool) external view returns (uint32) {}

    /**
     * @dev returns whether trading is enabled
     */
    function tradingEnabled(address pool) external view returns (bool) {}

    /**
     * @dev returns whether depositing is enabled
     */
    function depositingEnabled(address pool) external view returns (bool) {}

    /**
     * @dev returns whether the pool is stable
     */
    function isPoolStable(address pool) external view returns (bool) {}

    /**
     * @dev returns the pending withdrawals contract
     */
    function pendingWithdrawals() external view returns (address) {}

    /**
     * @dev returns the pool migrator contract
     */
    function poolMigrator() external view returns (address) {}

    /**
     * @dev returns the output amount when trading by providing the source amount
     */
    function tradeOutputBySourceAmount(
        address sourceToken,
        address targetToken,
        uint256 sourceAmount
    ) external view returns (uint256) {}

    /**
     * @dev returns the input amount when trading by providing the target amount
     */
    function tradeInputByTargetAmount(
        address sourceToken,
        address targetToken,
        uint256 targetAmount
    ) external view returns (uint256) {}

    /**
     * @dev returns whether the given request is ready for withdrawal
     */
    function isReadyForWithdrawal(uint256 id) external view returns (bool) {}

    /**
     * @dev converts the specified pool token amount to the underlying token amount
     */
    function poolTokenToUnderlying(address pool, uint256 poolTokenAmount) external view returns (uint256) {
        uint256 bntLQTYSupply = IERC20(pool).totalSupply();
        uint256 lqtyBalance = lqtyToken.balanceOf(address(network));

        if (bntLQTYSupply == 0) {
            return 0;
        }

        return poolTokenAmount * lqtyBalance / bntLQTYSupply;
    }

    /**
     * @dev converts the specified underlying base token amount to pool token amount
     */
    function underlyingToPoolToken(address pool, uint256 tokenAmount) external view returns (uint256) {
        uint256 bntLQTYSupply = IERC20(pool).totalSupply();
        uint256 lqtyBalance = lqtyToken.balanceOf(address(network));

        if (lqtyBalance == 0) {
            return 0;
        }

        return tokenAmount * bntLQTYSupply / lqtyBalance;
    }

    /**
     * @dev returns the amounts that would be returned if the position is currently withdrawn,
     * along with the breakdown of the base token and the BNT compensation
     */
    function withdrawalAmounts(address pool, uint256 poolTokenAmount) external view returns (WithdrawalAmounts memory) {}
}
