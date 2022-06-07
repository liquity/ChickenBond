// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract BLQTYToken is ERC20, Ownable {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    address public chickenBondManagerAddress;

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        chickenBondManagerAddress = _chickenBondManagerAddress;
        renounceOwnership();
    }

    function mint(address _to, uint256 _bLQTYAmount) external {
        _requireCallerIsChickenBondsManager();
        _mint(_to, _bLQTYAmount);
    }

    function burn(address _from, uint256 _bLQTYAmount) external {
        _requireCallerIsChickenBondsManager();
        _burn(_from, _bLQTYAmount);
    }

    function _requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == chickenBondManagerAddress, "BLQTYToken: Caller must be ChickenBondManager");
    }
}
