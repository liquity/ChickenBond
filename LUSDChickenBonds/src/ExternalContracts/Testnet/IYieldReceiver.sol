// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IYieldReceiver {
    function _getCurrentValue() external view returns (uint256);
    function _notifyYield(uint256 _amount) external;
}
