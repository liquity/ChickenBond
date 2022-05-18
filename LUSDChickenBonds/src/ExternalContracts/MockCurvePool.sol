// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../utils/console.sol";
import "../Interfaces/ILUSDToken.sol";
import "../Interfaces/ICurvePool.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MockCurvePool is ERC20, Ownable, ICurvePool {
    IERC20 public lusdToken;
   
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _lusdTokenAddress) external onlyOwner {
        lusdToken = ILUSDToken(_lusdTokenAddress);
    }

    function add_liquidity(uint256[2] memory _amounts, uint256) external {
        uint256 lusdAmount = _amounts[0];
        lusdToken.transferFrom(msg.sender, address(this), lusdAmount);
       
        uint256 lpShares = lusdAmount; // mock 1:1 shares:tokens
        _mint(msg.sender, lpShares);
    }

    function remove_liquidity_one_coin(uint256 _burn_amount, int128, uint256) external {
        uint lusdAmount = _burn_amount; // mock 1:1 shares:tokens
        lusdToken.transfer(msg.sender, lusdAmount);

        _burn(msg.sender, _burn_amount);
    }

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

    function totalSupply() public pure override (ICurvePool, ERC20) returns (uint256) {
        return 30e26; // artificial total share token supply balance
    }

    function get_dy_underlying(int128, int128, uint256 dx) external pure returns (uint256) {
        return dx; // Artificial LUSD-3CRV spot price of 1.0
    }
}
