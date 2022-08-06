// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./IMinter.sol";
import "./IYieldReceiver.sol";

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
