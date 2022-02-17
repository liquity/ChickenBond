// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../console.sol";
import "../Interfaces/ILUSDToken.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockYearnLUSDVault is Ownable {
    // ISLUSDToken public sLUSDToken;
    ILUSDToken public lusdToken;
   
    mapping (address => uint256) balances;
    uint public totalLUSDBalance;

    function setAddresses(address _lusdTokenAddress) external onlyOwner {
        lusdToken = ILUSDToken(_lusdTokenAddress);
    }

    function deposit (uint256 _lusdAmount) external {
        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);
        balances[msg.sender] += _lusdAmount;
        totalLUSDBalance += _lusdAmount;
    }

    function withdraw (uint256 _lusdAmount) external {
        lusdToken.transfer(msg.sender, _lusdAmount);
        balances[msg.sender] -= _lusdAmount;
        totalLUSDBalance -= _lusdAmount;
    }
}