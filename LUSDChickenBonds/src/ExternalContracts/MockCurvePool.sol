// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../Interfaces/ICurvePool.sol";
import "../test/TestContracts/LUSDTokenTester.sol";

import "forge-std/console.sol";


contract MockCurvePool is ERC20, Ownable, ICurvePool {
    LUSDTokenTester public lusdToken;

    uint256 private constant DEFAULT_PRANK_PRICE = 1e18;
    uint256 private nextPrankPrice = DEFAULT_PRANK_PRICE;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _lusdTokenAddress) external onlyOwner {
        lusdToken = LUSDTokenTester(_lusdTokenAddress);
    }

    function add_liquidity(uint256[2] memory _amounts, uint256) public returns (uint256) {
        nextPrankPrice = DEFAULT_PRANK_PRICE;

        uint256 lusdAmount = _amounts[0];
        lusdToken.transferFrom(msg.sender, address(this), lusdAmount);
       
        uint256 lpShares = lusdAmount; // mock 1:1 shares:tokens
        _mint(msg.sender, lpShares);

        return lpShares;
    }

    function add_liquidity(uint256[2] memory _amounts, uint256 _minLPTokens, address) public returns (uint256) {
        return add_liquidity(_amounts, _minLPTokens);
    }

    function remove_liquidity_one_coin(uint256 _burn_amount, int128, uint256) public {
        nextPrankPrice = DEFAULT_PRANK_PRICE;

        uint lusdAmount = _burn_amount; // mock 1:1 shares:tokens
        lusdToken.transfer(msg.sender, lusdAmount);

        _burn(msg.sender, _burn_amount);
    }

    function remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received, address) external {
        remove_liquidity_one_coin(_burn_amount, i, _min_received);
    }

    function remove_liquidity(uint256 burn_amount, uint256[2] memory _min_amounts) external {}

    function remove_liquidity(uint256 burn_amount, uint256[2] memory _min_amounts, address _receiver) external {}

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address _receiver) external returns (uint256) {}

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy, address _receiver) external returns (uint256) {}

    /* Simplified LP shares calculators. Shares issued/burned 1:1 with deposited/withdrawn LUSD respectively.
    * In practice, the conversion will be more complicated and will depend on the pool proportions and sizes. */
    function calc_withdraw_one_coin(uint256 _burn_amount, int128) external pure returns (uint256) {
        return _burn_amount;
    }

    function calc_token_amount(uint256[2] memory _amounts, bool) external pure returns (uint256) {
        return _amounts[0];
    }

    function balances(uint256) external pure returns (uint256) {
        return 30e26; // artificial token balances of curve pool (30m for LUSD and 3CRV)
    }

    function token() external view returns (address) {
        return address(this);
    }

    function totalSupply() public pure override (ICurvePool, ERC20) returns (uint256) {
        return 30e26; // artificial total share token supply balance
    }

    function get_dy_underlying(int128, int128, uint256 dx) external view returns (uint256) {
        return dx * nextPrankPrice / 1e18;
    }

    function get_dy(int128, int128, uint256 dx) external view returns (uint256) {
        return dx * nextPrankPrice / 1e18;
    }

    function setNextPrankPrice(uint256 _nextPrankPrice) external {
        nextPrankPrice = _nextPrankPrice;
    }

    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here
        _mint(_account, _amount);

        // Maintain 1:1 ratio between LP shares and LUSD in the pool
        lusdToken.unprotectedMint(address(this), _amount);
    }

    function get_virtual_price() external pure returns (uint256) {
        return 1e18;
    }

    function fee() external pure returns (uint256) {
        return 0;
    }

    function D() external pure returns (uint256) {
        return 0;
    }

    function future_A_gamma_time() external pure returns (uint256) {
        return 0;
    }
}
