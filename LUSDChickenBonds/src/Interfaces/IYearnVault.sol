// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

interface IYearnVault is IERC20 { 
    function deposit(uint256 _tokenAmount) external;

    function withdraw(uint256 _tokenAmount) external;
}