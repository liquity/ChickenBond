// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import { IYieldReceiver } from "./Harvester.sol";
import { IPricePrankAccomplice } from "./Shifter.sol";

contract TestnetCurvePool is IYieldReceiver, IPricePrankAccomplice, ERC20, Ownable {
    uint256 private constant DEFAULT_PRANK_PRICE = 1e18;

    IERC20 immutable private coin0;
    uint256 private _coin0Value;
    uint256 private _nextPrankPrice = DEFAULT_PRANK_PRICE;

    constructor(string memory _name, string memory _symbol, address _coin0) ERC20(_name, _symbol) {
        coin0 = IERC20(_coin0);
    }

    function add_liquidity(uint256[2] memory _amounts, uint256) external returns (uint256 sharesMinted)
    {
        require(_amounts[1] == 0, "TestnetCurvePool: only coin 0 deposits supported");

        uint256 _coin0Amount = _amounts[0];
        sharesMinted = _coin0Amount * 1e18 / get_virtual_price();
        _coin0Value += _coin0Amount;

        coin0.transferFrom(msg.sender, address(this), _coin0Amount);
        _mint(msg.sender, sharesMinted);

        _nextPrankPrice = DEFAULT_PRANK_PRICE;
    }

    function remove_liquidity_one_coin(uint256 _sharesToBurn, int128 i, uint256) external returns (uint256 coinWithdrawn)
    {
        require(i == 0, "TestnetCurvePool: only coin 0 withdrawal supported");

        coinWithdrawn = _sharesToBurn * get_virtual_price() / 1e18;
        _coin0Value -= coinWithdrawn;

        _burn(msg.sender, _sharesToBurn);
        coin0.transfer(msg.sender, coinWithdrawn);

        _nextPrankPrice = DEFAULT_PRANK_PRICE;
    }

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256) {
        require(0 <= i && i <= 1, "TestnetCurvePool: i must be in range [0, 1]");
        require(0 <= j && j <= 1, "TestnetCurvePool: j must be in range [0, 1]");
        require(i != j, "TestnetCurvePool: i and j must not be equal");

        return i == 0 ? dx * _nextPrankPrice / 1e18 : dx * 1e18 / _nextPrankPrice;
    }

    function get_virtual_price() public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply > 0 ? _coin0Value * 1e18 / supply : 1e18;
    }

    function fee() external pure returns (uint256) {
        return 0;
    }

    function _notifyYield(uint256 _amount) external onlyOwner {
        require(
            coin0.balanceOf(address(this)) >= _coin0Value + _amount,
            "TestnetCurvePool: yield more than coin balance increase"
        );

        _coin0Value += _amount;
    }

    function _getCurrentValue() external view returns (uint256) {
        return _coin0Value;
    }

    function _setNextPrankPrice(uint256 _price) external onlyOwner {
        _nextPrankPrice = _price;
    }
}
