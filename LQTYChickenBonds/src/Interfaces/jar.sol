// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


interface IJar is IERC20 {
    function token() external view returns (address);

    function reward() external view returns (address);

    function claimInsurance() external; // NOTE: Only yDelegatedVault implements this

    function getRatio() external view returns (uint256);

    function depositAll() external;

    function balance() external view returns (uint256);

    function deposit(uint256) external;

    function withdrawAll() external;

    function withdraw(uint256) external;

    function earn() external;

    function decimals() external view returns (uint8);
}
