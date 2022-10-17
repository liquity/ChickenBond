pragma solidity ^0.8.11;

import "./EggTraitWeights.sol";
//import "forge-std/console.sol";


contract ChickenInTraitWeights is EggTraitWeights {
    uint256 constant EGG_CHICKEN_REPEAT_FACTOR = 120e16;
    // See: https://www.desmos.com/calculator/fctburkmtg
    uint256 constant R3 = 52e16;
    uint256 constant ALPHA3 = 1e18 / uint256(3);
    // See: https://www.desmos.com/calculator/5j3crba9t1
    uint256 constant R4 = 20e16;
    uint256 constant ALPHA4 = 40e16;

    // We are using the same colors for Chicken and Shell, so no need for `enum Chicken`
    // No need for base chickenWeights array either
    //uint256[13] public chickenWeights = [11e16, 9e16, 9e16, 10e16, 10e16, 10e16, 10e16, 10e16, 75e15, 6e16, 4e16, 25e15, 1e16];
    uint256[13] public troveSizeMaxMultiplier = [0, 0, 0, 0, 0, 0, 0, 0, 120e16, 150e16, 250e16, 400e16, 1000e16];

    function _getChickenAffinityWeights(ShellColor shellColor, uint256 troveFactor) internal view returns (uint256[13] memory chickenWeightsCached) {
        uint256 finalNonRareAccumulatedWeight = 1e18;
        uint256 baseNonRareAccumulatedWeight = 1e18;
        // Rare traits: Bronze to Luminous
        for (uint256 i = uint256(ShellColor.Bronze); i < chickenWeightsCached.length; i++) {
            chickenWeightsCached[i] = shellWeights[i] * (1e18 + troveFactor * (troveSizeMaxMultiplier[i] - 1e18) / 1e18) / 1e18;
            if (i == uint256(shellColor)) { // repeat probability
                chickenWeightsCached[i] = chickenWeightsCached[i] * EGG_CHICKEN_REPEAT_FACTOR / 1e18;
            }
            finalNonRareAccumulatedWeight -= chickenWeightsCached[i];
            baseNonRareAccumulatedWeight -= shellWeights[i];
        }
        // Regular traits
        for (uint256 i = 0; i < uint256(ShellColor.Bronze); i++) {
            chickenWeightsCached[i] = shellWeights[i] * finalNonRareAccumulatedWeight / baseNonRareAccumulatedWeight;
        }
    }

    // Turn the pseudo-random number `rand` -- 18 digit FP in range [0,1) -- into a Chicken (Shell) color.
    function _getChickenColor(uint256 rand, ShellColor shellColor, uint256 troveFactor) internal view returns (ShellColor) {
        // first adjust weights for affinity
        uint256[13] memory chickenWeightsCached = _getChickenAffinityWeights(shellColor, troveFactor);

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

    function _getChickenTrait9(uint256 rand, uint256 troveFactor) internal pure returns (uint8) {
        // TODO: should we hardcode this? Gas doesn’t really matter here as we are just static-calling them
        uint256 tier1Probability = ((2e18 - ALPHA3) / 3 - R3 * troveFactor / 1e18) / 3;
        uint256 tier2Probability = 1e18 / uint256(9);
        uint256 tier3Probability = (ALPHA3 / 3 + R3 * troveFactor / 1e18) / 3;

        uint256 needle = tier1Probability;
        if (rand < needle) { return 1; }
        needle += tier1Probability;
        if (rand < needle) { return 2; }
        needle += tier1Probability;
        if (rand < needle) { return 3; }
        needle += tier2Probability;
        if (rand < needle) { return 4; }
        needle += tier2Probability;
        if (rand < needle) { return 5; }
        needle += tier2Probability;
        if (rand < needle) { return 6; }
        needle += tier3Probability;
        if (rand < needle) { return 7; }
        needle += tier3Probability;
        if (rand < needle) { return 8; }
        return 9;
    }

    function _getChickenComb(uint256 rand, uint256 troveFactor) internal pure returns (uint8) {
        return _getChickenTrait9(rand, troveFactor);
    }

    function _getChickenTail(uint256 rand, uint256 troveFactor) internal pure returns (uint8) {
        return _getChickenTrait9(rand, troveFactor);
    }

    function _getChickenBeak(uint256 rand, uint256 troveFactor) internal pure returns (uint8) {
        uint256 tier1Probability = (1e18 + 2 * ALPHA4) / 4 - 2 * R4 * troveFactor / 1e18;
        uint256 tier2Probability = (1e18 + ALPHA4) / 4 - R4 * troveFactor / 1e18;
        uint256 tier3Probability = (1e18 - ALPHA4) / 4 + R4 * troveFactor / 1e18;

        uint256 needle = tier1Probability;
        if (rand < needle) { return 1; }
        needle += tier2Probability;
        if (rand < needle) { return 2; }
        needle += tier3Probability;
        if (rand < needle) { return 3; }
        return 4;
    }

    function _getChickenWing(uint256 rand, uint256 troveFactor) internal pure returns (uint8) {

        uint256 tier1Probability = (2e18 - ALPHA3) / 3 - R3 * troveFactor / 1e18;
        uint256 tier2Probability = 1e18 / uint256(3);

        uint256 needle = tier1Probability;
        if (rand < needle) { return 1; }
        needle += tier2Probability;
        if (rand < needle) { return 2; }
        return 3;
    }
}
