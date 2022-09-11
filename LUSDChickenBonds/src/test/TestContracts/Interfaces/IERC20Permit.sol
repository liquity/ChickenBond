// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IERC20Permit is IERC20 {
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function domainSeparator() external view returns (bytes32);
    function permitTypeHash() external view returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function name() external view returns (string memory);
}
