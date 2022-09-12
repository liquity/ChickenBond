// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IMinter {
    function mint(address _to, uint256 _amount) external;
}

interface IYieldReceiver {
    function _getCurrentValue() external view returns (uint256);
    function _notifyYield(uint256 _amount) external;
}

contract Harvester {
    struct Target {
        uint256 apr;
        IYieldReceiver receiver;
    }

    IMinter public immutable minter;
    uint256 public lastHarvested;
    Target[] public targets;

    constructor(address _minter, Target[] memory _targets) {
        minter = IMinter(_minter);
        lastHarvested = block.timestamp;

        for (uint256 i = 0; i < _targets.length; ++i) {
            targets.push(_targets[i]);
        }
    }

    function harvest() external {
        uint256 timeSinceLastHarvest = block.timestamp - lastHarvested;

        for (uint256 i = 0; i < targets.length; ++i) {
            Target memory target = targets[i];
            uint256 value = target.receiver._getCurrentValue();
            uint256 yield = value * target.apr / 1e18 * timeSinceLastHarvest / 365 days;

            minter.mint(address(target.receiver), yield);
            target.receiver._notifyYield(yield);
        }

        lastHarvested = block.timestamp;
    }
}
