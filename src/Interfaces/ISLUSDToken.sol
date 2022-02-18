// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

interface ISLUSDToken is IERC20 {
    function mint(address _to, uint256 _sLUSDAmount) external;
}