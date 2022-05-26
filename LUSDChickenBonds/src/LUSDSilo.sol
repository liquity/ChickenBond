pragma solidity ^0.8.10;

import "./Interfaces/ILUSDToken.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract LUSDSilo is Ownable {
    ILUSDToken public lusdToken; 
    address public chickenBondManagerAddress;

    function initialize(address _chickenBondManagerAddress, address _lusdTokenAddress) external onlyOwner {
        // Set addresses, and give CBM (trusted system contract) infinite approval for LUSD.
        chickenBondManagerAddress = _chickenBondManagerAddress;
        lusdToken = ILUSDToken(_lusdTokenAddress);
        lusdToken.approve(chickenBondManagerAddress, type(uint256).max);

        renounceOwnership();
    } 
}