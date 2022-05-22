// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../Interfaces/IYearnVault.sol";
import "../utils/console.sol";
import "../test/TestContracts/LUSDTokenTester.sol";

contract MockYearnVault is ERC20, Ownable, IYearnVault {
    address public token;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _tokenAddress) external onlyOwner {
        token = _tokenAddress;
    }

    function deposit(uint256 _tokenAmount) external returns (uint256) {
        uint lpShares = _tokenAmount * 1e18 / pricePerShare();

        LUSDTokenTester(token).transferFrom(msg.sender, address(this), _tokenAmount);
        _mint(msg.sender, lpShares);

        return lpShares;
    }

    function withdraw(uint256 _lpShares) external returns (uint256) {
        uint tokenAmount = _lpShares * pricePerShare() / 1e18;

        LUSDTokenTester(token).transfer(msg.sender, tokenAmount);
        _burn(msg.sender, _lpShares);

        return tokenAmount;
    }

    // Mimic yield harvest - this actually belongs to Strategy contract
    function harvest(uint256 _amount) external {
        LUSDTokenTester(token).unprotectedMint(address(this), _amount);
    }

    function pricePerShare() public view returns (uint256) {
        uint256 totalSupplyCached = totalSupply();

        if (totalSupplyCached == 0) {
            return 1e18;
        }

        return LUSDTokenTester(token).balanceOf(address(this)) * 1e18 / totalSupplyCached;
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

    function setDepositLimit(uint256 _limit) external {
        // nothing
    }

    function withdrawalQueue(uint256) external returns (address) {
        revert("MockYearnVault: withdrawalQueue() not implemented");
    }
}
