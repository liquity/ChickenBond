pragma solidity ^0.8.11;

import "./EggTraitWeights.sol";


contract ChickenOutTraitWeights is EggTraitWeights {
    uint256 constant EGG_CHICKEN_REPEAT_PROBABILITY = 30e16;

    // We are using the same colors for Chicken and Shell, so no need for `enum Chicken`
    // No need for base chickenWeights array either
    //uint256[13] public chickenWeights = [11e16, 9e16, 9e16, 10e16, 10e16, 10e16, 10e16, 10e16, 75e15, 6e16, 4e16, 25e15, 1e16];

    function _getChickenAffinityWeights(ShellColor shellColor) internal view returns (uint256[13] memory chickenWeightsCached) {
        for (uint256 i = 0; i < chickenWeightsCached.length; i++) {
            if (i == uint256(shellColor)) { // repeat probability
                chickenWeightsCached[i] = EGG_CHICKEN_REPEAT_PROBABILITY;
            } else { // we accomodate the rest of weights to the remaining of the repeating probability
                chickenWeightsCached[i] = shellWeights[i] * (1e18 - EGG_CHICKEN_REPEAT_PROBABILITY) / (1e18 - shellWeights[uint256(shellColor)]);
            }
        }
    }

    // Turn the pseudo-random number `rand` -- 18 digit FP in range [0,1) -- into a Chicken (Shell) color.
    function _getChickenColor(uint256 rand, ShellColor shellColor) internal view returns (ShellColor) {
        // first adjust weights for affinity
        uint256[13] memory chickenWeightsCached = _getChickenAffinityWeights(shellColor);

        // then compute color
        uint256 needle = chickenWeightsCached[uint256(ShellColor.OffWhite)];
        if (rand < needle) { return ShellColor.OffWhite; }
        needle += chickenWeightsCached[uint256(ShellColor.LightBlue)];
        if (rand < needle) { return ShellColor.LightBlue; }
        needle += chickenWeightsCached[uint256(ShellColor.DarkerBlue)];
        if (rand < needle) { return ShellColor.DarkerBlue; }
        needle += chickenWeightsCached[uint256(ShellColor.LighterOrange)];
        if (rand < needle) { return ShellColor.LighterOrange; }
        needle += chickenWeightsCached[uint256(ShellColor.LightOrange)];
        if (rand < needle) { return ShellColor.LightOrange; }
        needle += chickenWeightsCached[uint256(ShellColor.DarkerOrange)];
        if (rand < needle) { return ShellColor.DarkerOrange; }
        needle += chickenWeightsCached[uint256(ShellColor.LightGreen)];
        if (rand < needle) { return ShellColor.LightGreen; }
        needle += chickenWeightsCached[uint256(ShellColor.DarkerGreen)];
        if (rand < needle) { return ShellColor.DarkerGreen; }
        needle += chickenWeightsCached[uint256(ShellColor.Bronze)];
        if (rand < needle) { return ShellColor.Bronze; }
        needle += chickenWeightsCached[uint256(ShellColor.Silver)];
        if (rand < needle) { return ShellColor.Silver; }
        needle += chickenWeightsCached[uint256(ShellColor.Gold)];
        if (rand < needle) { return ShellColor.Gold; }
        needle += chickenWeightsCached[uint256(ShellColor.Rainbow)];
        if (rand < needle) { return ShellColor.Rainbow; }
        return ShellColor.Luminous;
    }
}
