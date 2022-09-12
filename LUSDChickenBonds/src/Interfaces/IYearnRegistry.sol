// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;


interface IYearnRegistry {
    function latestVault(address _tokenAddress) external returns (address);
}

