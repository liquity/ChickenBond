// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./BaseMath.sol";


// taken from: https://github.com/liquity/dev/blob/8371355b2f11bee9fa599f9223f4c2f6f429351f/packages/contracts/contracts/Dependencies/LiquityMath.sol
contract ChickenMath is BaseMath {

    /*
     * Multiply two decimal numbers and use normal rounding rules:
     * -round product up if 19'th mantissa digit >= 5
     * -round product down if 19'th mantissa digit < 5
     *
     * Used only inside the exponentiation, decPow().
     */
    function decMul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y + DECIMAL_PRECISION / 2) / DECIMAL_PRECISION;
    }

    /*
     * decPow: Exponentiation function for 18-digit decimal base, and integer exponent n.
     *
     * Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity.
     *
     * Called by ChickenBondManager.calcRedemptionFeePercentage, that represents time in units of minutes:
     *
     * The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
     * "minutes in 1000 years": 60 * 24 * 365 * 1000
     *
     * If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
     * negligibly different from just passing the cap, since:
     * the decayed base rate will be 0 for 1000 years or > 1000 years
     */
    function decPow(uint256 _base, uint256 _exponent) internal pure returns (uint) {

        if (_exponent > 525600000) {_exponent = 525600000;}  // cap to avoid overflow

        if (_exponent == 0) {return DECIMAL_PRECISION;}

        uint256 y = DECIMAL_PRECISION;
        uint256 x = _base;
        uint256 n = _exponent;

        // Exponentiation-by-squaring
        while (n > 1) {
            if (n % 2 != 0) {
                y = decMul(x, y);
            }
            x = decMul(x, x);
            n = n / 2;
        }

        return decMul(x, y);
    }
}
