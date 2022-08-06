// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IMinter {
    function mint(address _to, uint256 _amount) external;
}
