pragma solidity ^0.8.10;

// Dummy contract to get Slither to work
// It expects every build artifact to include "bytecode"
contract TestUtilsIsNotAContract {}

// Coerce x into range [a, b] (inclusive) by modulo division.
// Preserves x if it's already within range.
function coerce(uint256 x, uint256 a, uint256 b) pure returns (uint256) {
    (uint256 min, uint256 max) = a < b ? (a, b) : (b, a);

    if (min <= x && x <= max) {
        return x;
    }

    // The only case in which this would overflow is min = 0, max = 2**256-1;
    // however in that case we would have returned by now (see above).
    uint256 modulus = max - min + 1;

    if (x >= min) {
        return min + (x - min) % modulus;
    } else {
        // x < min, therefore x < max, also
        return max - (max - x) % modulus;
    }
}
