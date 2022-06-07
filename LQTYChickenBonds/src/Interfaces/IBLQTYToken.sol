// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IBLQTYToken is IERC20 {
    function mint(address _to, uint256 _bLQTYAmount) external;

    function burn(address _from, uint256 _bLQTYAmount) external;
}
