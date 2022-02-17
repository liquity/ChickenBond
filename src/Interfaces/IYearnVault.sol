
// SPDX-License-Identifier: UNLICENSED

// pragma solidity 0.8.10;

interface IYearnVault { 
     function deposit (uint256 _lusdAmount) external;

    function withdraw (uint256 _lusdAmount) external;
}
