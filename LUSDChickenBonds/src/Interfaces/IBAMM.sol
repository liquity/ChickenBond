// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


interface IBAMM {
    function deposit(uint256 lusdAmount) external;

    function withdraw(uint256 lusdAmount, address to) external;

    function getLUSDValue() external view returns (uint256, uint256, uint256);

    function setChicken(address _chicken) external;
}
