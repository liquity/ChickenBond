pragma solidity ^0.8.11;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/ChickenInTraitWeightsWrap.sol";


contract ChickenInTraitWeightTest is BaseTest {
    function _checkWeights(uint256[13] memory weights, uint256[13] memory weightsExpected) internal {
        uint256 total;

        for (uint256 i = 0; i < 13; i++) {
            //console.log(weights[i], "w");
            //console.log(weightsExpected[i], "w-e");
            assertApproximatelyEqual(weights[i], weightsExpected[i], 1e12, "Weight mismatch");
            total += weights[i];
        }

        //console.log(total, "total");
        assertApproximatelyEqual(total, 1e18, 1e11, "Sum of affinity weights should be 100%");
    }

    // see: https://docs.google.com/spreadsheets/d/1GfbKWmx8OY62qvgbM4t-_acjdhXR5DMtY8zRxBPCn4g/edit#gid=423371733

    function testGetChickenColor() public {
        ChickenInTraitWeightsWrap chickenInTraitWeights = new ChickenInTraitWeightsWrap();

        uint256 troveFactor = 10e16;

        // Shell color non special (LightBlue)

        // OffWhite
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(0, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite (lower bound)"
        );
        /**/
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(10624050e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite (upper bound)"
        );

        // LightBlue
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(10624051e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(19316455e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue (upper bound)"
        );

        // (...)
        // Gold
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(90250000e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(94849999e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold (upper bound)"
        );

        // Rainbow
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(94850000e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(98099999e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow (upper bound)"
        );

        // Luminous
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(98100000e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(99999999e10, EggTraitWeights.ShellColor.LightBlue, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous (upper bound)"
        );

        // (...)
        // Shell color Gold

        // OffWhite
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(0, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(10495949e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite (upper bound)"
        );

        // LightBlue
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(10495950e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(19083544e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue (upper bound)"
        );

        // (...)
        // Gold
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(89330000e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(94849999e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold (upper bound)"
        );

        // Rainbow
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(94850000e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(98099999e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow (upper bound)"
        );

        // Luminous
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(98100000e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous (lower bound)"
        );
        assertEq(
            uint256(chickenInTraitWeights.getChickenColor(99999999e10, EggTraitWeights.ShellColor.Gold, troveFactor)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous (upper bound)"
        );
        /**/
    }

    // For comb and tail
    function testGetChickenTrait9() public {
        ChickenInTraitWeightsWrap chickenInTraitWeights = new ChickenInTraitWeightsWrap();

        uint256 troveFactor = 1250e14;

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(0, troveFactor)),
            1,
            "Trait9 should 1 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(16351851e10, troveFactor)),
            1,
            "Trait9 should 1 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(16351852e10, troveFactor)),
            2,
            "Trait9 should 2 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(32703703e10, troveFactor)),
            2,
            "Trait9 should 2 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(60166667e10, troveFactor)),
            5,
            "Trait9 should 5 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(71277777e10, troveFactor)),
            5,
            "Trait9 should 5 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(88259260e10, troveFactor)),
            8,
            "Trait9 should 8 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(94129629e10, troveFactor)),
            8,
            "Trait9 should 8 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(94129630e10, troveFactor)),
            9,
            "Trait9 should 1 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenTrait9(99999999e10, troveFactor)),
            9,
            "Trait9 should 9 (upper bound)"
        );
    }

    function testGetChickenBeak() public {
        ChickenInTraitWeightsWrap chickenInTraitWeights = new ChickenInTraitWeightsWrap();

        uint256 troveFactor = 1250e14;

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(0, troveFactor)),
            1,
            "Beak should 1 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(39999999e10, troveFactor)),
            1,
            "Beak should 1 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(40000000e10, troveFactor)),
            2,
            "Beak should 2 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(72499999e10, troveFactor)),
            2,
            "Beak should 2 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(72500000e10, troveFactor)),
            3,
            "Beak should 3 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(89999999e10, troveFactor)),
            3,
            "Beak should 3 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(90000000e10, troveFactor)),
            4,
            "Beak should 4 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenBeak(99999999e10, troveFactor)),
            4,
            "Beak should 4 (upper bound)"
        );
    }

    function testGetChickenWing() public {
        ChickenInTraitWeightsWrap chickenInTraitWeights = new ChickenInTraitWeightsWrap();

        uint256 troveFactor = 1250e14;

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(0, troveFactor)),
            1,
            "Wing should 1 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(49055555e10, troveFactor)),
            1,
            "Wing should 1 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(49055556e10, troveFactor)),
            2,
            "Wing should 2 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(82388888e10, troveFactor)),
            2,
            "Wing should 2 (upper bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(82388889e10, troveFactor)),
            3,
            "Wing should 3 (lower bound)"
        );

        assertEq(
            uint256(chickenInTraitWeights.getChickenWing(99999999e10, troveFactor)),
            3,
            "Wing should 3 (upper bound)"
        );
    }
}
