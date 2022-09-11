// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../Interfaces/IBAMM.sol";
import "../test/TestContracts/LUSDTokenTester.sol";

import "forge-std/console.sol";


contract MockBAMMSPVault is IBAMM {
    LUSDTokenTester public lusdToken;
    uint256 lusdValue;

    constructor(address _lusdTokenAddress) {
        lusdToken = LUSDTokenTester(_lusdTokenAddress);
    }

    function deposit(uint256 _lusdAmount) external {
        lusdValue += _lusdAmount;
        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        return;
    }

    function withdraw (uint256 _lusdAmount, address _to) external {
        lusdValue -= _lusdAmount;
        lusdToken.transfer(_to, _lusdAmount);

        return;
    }

    function swap(uint lusdAmount, uint minEthReturn, address payable dest) public returns(uint) {}

    function getSwapEthAmount(uint lusdQty) public view returns(uint ethAmount, uint feeLusdAmount) {}

    function getLUSDValue() external view returns (uint256, uint256, uint256) {
        uint256 lusdBalance = lusdToken.balanceOf(address(this));
        return (lusdValue, lusdBalance, 0);
    }

    function setChicken(address _chicken) external {}
}
