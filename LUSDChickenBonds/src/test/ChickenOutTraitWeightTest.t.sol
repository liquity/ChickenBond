pragma solidity ^0.8.11;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/ChickenOutTraitWeightsWrap.sol";


contract ChickenOutTraitWeightTest is BaseTest {
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

    // see: https://docs.google.com/spreadsheets/d/1GfbKWmx8OY62qvgbM4t-_acjdhXR5DMtY8zRxBPCn4g/edit#gid=879546370

    function testGetChickenColor() public {
        ChickenOutTraitWeightsWrap chickenOutTraitWeights = new ChickenOutTraitWeightsWrap();

        // Shell color non special

        // OffWhite
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(0, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(29999999e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite"
        );

        // LightBlue
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(30000000e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(37078651e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue"
        );

        // (...)
        // Gold
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(94101124e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(97247191e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(97247192e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99213483e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow"
        );

        // Luminous
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99213484e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99999999e10, EggTraitWeights.ShellColor.OffWhite)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous"
        );

        // (...)
        // Shell color rainbow

        // OffWhite
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(0, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(7897435e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Chicken color should be OffWhite"
        );

        // LightBlue
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(7897436e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(14358974e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Chicken color should be LightBlue"
        );

        // (...)
        // Gold
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(66410257e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(69282051e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Chicken color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(69282052e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99282051e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Chicken color should be rainbow"
        );

        // Luminous
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99282052e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous"
        );
        assertEq(
            uint256(chickenOutTraitWeights.getChickenColor(99999999e10, EggTraitWeights.ShellColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Chicken color should be luminous"
        );
    }
}
