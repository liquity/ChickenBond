// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./Harvester.sol";
import "./Shifter.sol";

contract Prankster is Harvester, Shifter {
    constructor(
        address _minter,
        Target[] memory _yieldTargets,
        address _shiftee,
        address _pricePrankAccomplice
    )
        Harvester(_minter, _yieldTargets)
        Shifter(_shiftee, _pricePrankAccomplice)
    {}
}
