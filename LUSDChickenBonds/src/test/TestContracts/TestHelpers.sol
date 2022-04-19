pragma solidity ^0.8.10;


contract TestHelpers {
    function isMaxError(uint256 a, uint256 b, uint256 maxError) internal returns (bool) {
        uint256 diff = a >= b ? a - b : b - a;
        return diff <= maxError;
    }
}
