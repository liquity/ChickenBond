// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestnetYearnVault is ERC20 {
    IERC20 public immutable token;

    constructor(string memory _name, string memory _symbol, address _token) ERC20(_name, _symbol) {
        token = IERC20(_token);
    }

    function deposit(uint256 _tokensToDeposit) external returns (uint256 sharesMinted) {
        sharesMinted = _tokensToDeposit * 1e18 / pricePerShare();
        token.transferFrom(msg.sender, address(this), _tokensToDeposit);
        _mint(msg.sender, sharesMinted);
    }

    function withdraw(uint256 _sharesToBurn) external returns (uint256 tokensWithdrawn) {
        tokensWithdrawn = _sharesToBurn * pricePerShare() / 1e18;
        _burn(msg.sender, _sharesToBurn);
        token.transfer(msg.sender, tokensWithdrawn);
    }

    function pricePerShare() public pure returns (uint256) {
        return 1e18;
    }
}
