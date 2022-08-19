// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import { IMinter } from "./Harvester.sol";

contract ERC20Faucet is IMinter, ERC20, Ownable {
    uint256 public immutable tapAmount;
    uint256 public immutable tapPeriod;

    mapping(address => uint256) public lastTapped;

    constructor(string memory _name, string memory _symbol, uint256 _tapAmount, uint256 _tapPeriod)
        ERC20(_name, _symbol)
    {
        tapAmount = _tapAmount;
        tapPeriod = _tapPeriod;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function tap() external {
        uint256 timeNow = _requireNotRecentlyTapped();

        _mint(msg.sender, tapAmount);
        lastTapped[msg.sender] = timeNow;
    }

    function _requireNotRecentlyTapped() internal view returns (uint256 timeNow) {
        timeNow = block.timestamp / tapPeriod;
        require(timeNow > lastTapped[msg.sender], "ERC20Faucet: must wait before tapping again");
    }
}