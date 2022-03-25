// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../console.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MockYearnVault is ERC20, Ownable {
    // ISLUSDToken public sLUSDToken;
    IERC20 public token;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _tokenAddress) external onlyOwner {
        token = IERC20(_tokenAddress);
    }

    function deposit(uint256 _tokenAmount) external {
        token.transferFrom(msg.sender, address(this), _tokenAmount);

        uint lpShares = calcTokenToYToken(_tokenAmount);
        _mint(msg.sender, lpShares);
    }

    function withdraw (uint256 _lpShares) external {
        uint tokenAmount = _lpShares;
        token.transfer(msg.sender, tokenAmount);

        _burn(msg.sender, _lpShares);
    }

    /* Simplified LP shares calculators. Shares issued/burned 1:1 with deposited/withdrawn LUSD respectively.
    * In practice, the conversion will be more complicated and will depend on yield earned by the vault. */
    function calcTokenToYToken(uint256 _tokenAmount) public pure returns (uint256) {
        return _tokenAmount;
    }

    // function lockedProfit() public pure returns (uint256) {
    //     return 0;
    // }

    // function lockedProfitDegradation() public pure returns (uint256) {
    //     return 0;
    // }

    // // Some Yearn vaults have this typo ("degration" vs "degradation")
    // function lockedProfitDegration() public pure returns (uint256) {
    //     return 0;
    // }

    function pricePerShare() public pure returns (uint256) {
        return 1;
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