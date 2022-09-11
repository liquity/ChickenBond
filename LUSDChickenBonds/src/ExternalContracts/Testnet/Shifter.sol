// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IShiftee {
    function shiftLUSDFromSPToCurve(uint256 _maxLUSDToShift) external;
    function shiftLUSDFromCurveToSP(uint256 _maxLUSDToShift) external;
}

interface IPricePrankAccomplice {
    function _setNextPrankPrice(uint256 _price) external;
}

contract Shifter is IShiftee {
    IShiftee public immutable shiftee;
    IPricePrankAccomplice public immutable accomplice;

    constructor(address _shiftee, address _accomplice) {
        shiftee = IShiftee(_shiftee);
        accomplice = IPricePrankAccomplice(_accomplice);
    }

    function shiftLUSDFromSPToCurve(uint256 _maxLUSDToShift) external {
        accomplice._setNextPrankPrice(1.01e18);
        shiftee.shiftLUSDFromSPToCurve(_maxLUSDToShift);
    }

    function shiftLUSDFromCurveToSP(uint256 _maxLUSDToShift) external {
        accomplice._setNextPrankPrice(0.99e18);
        shiftee.shiftLUSDFromCurveToSP(_maxLUSDToShift);
    }
}
