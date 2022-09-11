// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../test/TestContracts/LUSDTokenTester.sol";

import "forge-std/console.sol";


contract MockYearnVault is ERC20, Ownable {
    // IBLUSDToken public bLUSDToken;
    LUSDTokenTester public token;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _tokenAddress) external onlyOwner {
        token = LUSDTokenTester(_tokenAddress);
    }

    function deposit(uint256 _tokenAmount) external returns (uint256) {
        uint lpShares = calcTokenToYToken(_tokenAmount);
        token.transferFrom(msg.sender, address(this), _tokenAmount);

        _mint(msg.sender, lpShares);
       
        return lpShares;
    }

    function withdraw (uint256 _lpShares) external returns (uint256) {
        uint tokenAmount = calcYTokenToToken(_lpShares);
        token.transfer(msg.sender, tokenAmount);

        _burn(msg.sender, _lpShares);

        return tokenAmount;
    }

    // Mimic yield harvest - this actually belongs to Strategy contract
    function harvest(uint256 _amount) external {
        token.unprotectedMint(address(this), _amount);
    }

    function calcTokenToYToken(uint256 _tokenAmount) public view returns (uint256) {
        if (token.balanceOf(address(this)) == 0 || totalSupply() == 0) {
            return _tokenAmount;
        }
        return _tokenAmount * totalSupply() / token.balanceOf(address(this));
    }

    function calcYTokenToToken(uint256 _yTokenAmount) public view returns (uint256) {
        assert(totalSupply() > 0);
        return _yTokenAmount * token.balanceOf(address(this)) / totalSupply();
    }

    function pricePerShare() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        }
        return token.balanceOf(address(this)) * 1e18 / totalSupply();
    }

    function lastReport() public pure returns (uint256) {
        return 1e6;
    }

    function totalDebt() public pure returns (uint256) {
        return 0;
    }

    function availableDepositLimit() public pure returns (uint256) {
        return 20e18;
    }
}
