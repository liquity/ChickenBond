// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../console.sol";
import "../Interfaces/ILUSDToken.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockYearnLUSDVault is Ownable {
    // ISLUSDToken public sLUSDToken;
    ILUSDToken public lusdToken;
   
    mapping (address => uint256) balances;

    function setAddresses(address _lusdTokenAddress) external onlyOwner {
        lusdToken = ILUSDToken(_lusdTokenAddress);
    }

    function deposit (uint256 _lusdAmount) external {
        console.log("here 1");
        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);
        console.log("here 2");
        balances[msg.sender] += _lusdAmount;
        console.log("here 3");
    }

    function withdraw (uint256 _lusdAmount) external {
        lusdToken.transfer(msg.sender, _lusdAmount);
        balances[msg.sender] -= _lusdAmount;
    }
}