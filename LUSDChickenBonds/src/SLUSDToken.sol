// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./console.sol";

contract SLUSDToken is ERC20, Ownable {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
  
    address public chickenBondManagerAddress;

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        chickenBondManagerAddress = _chickenBondManagerAddress;
        renounceOwnership();
    }

    function mint(address _to, uint256 _sLUSDAmount) external {
        _requireCallerIsChickenBondsManager();
        _mint(_to, _sLUSDAmount);
    }

    function burn(address _from, uint256 _sLUSDAmount) external {
        _requireCallerIsChickenBondsManager();
        _burn(_from, _sLUSDAmount);
    }

    function _requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == chickenBondManagerAddress, "SLUSDToken: Caller must be ChickenBondManager");
    }
}