pragma solidity ^0.8.10;

import "./Interfaces/IChickenBondManager.sol";
import "./Interfaces/ILUSDToken.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LUSDSilo is Ownable {
    ILUSDToken public lusdToken; 
    address public chickenBondManagerAddress;

    function initialize(address _chickenBondManagerAddress) external onlyOwner {
        // Set addresses, and give CBM (trusted system contract) infinite approval for LUSD.
        chickenBondManagerAddress = _chickenBondManagerAddress;
        lusdToken = ILUSDToken(IChickenBondManager(_chickenBondManagerAddress).lusdToken());
        lusdToken.approve(_chickenBondManagerAddress, type(uint256).max);

        renounceOwnership();
    } 
}
