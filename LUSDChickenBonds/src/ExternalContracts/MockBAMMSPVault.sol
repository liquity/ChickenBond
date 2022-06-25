// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../Interfaces/IBAMM.sol";
import "../test/TestContracts/LUSDTokenTester.sol";

import "forge-std/console.sol";


contract MockBAMMSPVault is IBAMM {
    LUSDTokenTester public lusdToken;

    constructor(address _lusdTokenAddress) {
        lusdToken = LUSDTokenTester(_lusdTokenAddress);
    }

    function deposit(uint256 _lusdAmount) external {
        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        return;
    }

    function withdraw (uint256 _lusdAmount, address _to) external {
        lusdToken.transfer(_to, _lusdAmount);

        return;
    }

    function getLUSDValue() external view returns (uint256, uint256, uint256) {
        uint256 lusdBalance = lusdToken.balanceOf(address(this));
        return (lusdBalance, lusdBalance, 0);
    }
}
