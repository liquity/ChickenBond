pragma solidity ^0.8.11;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../Interfaces/IPickleJar.sol";


contract MockPickleJar is ERC20, IPickleJar {
    uint256 private ratio;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setRatio(uint256 _ratio) external {
        ratio = _ratio;
    }

    function getRatio() external view returns (uint256) {
        return ratio;
    }
}
