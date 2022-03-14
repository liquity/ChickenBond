// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

interface ICurvePool is IERC20 { 
    function add_liquidity(uint256 _LUSD3CRVAmount) external;

    function remove_liquidity(uint256 _LUSD3CRVAmount) external;

    function calcLUSDToLUSD3CRV(uint256 _LUSD3CRVAmount) external pure returns (uint256);

    function calcLUSD3CRVToLUSD(uint256 _LUSD3CRVAmount) external pure returns (uint256);
}