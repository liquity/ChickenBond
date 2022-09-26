// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/GenerativeEggArtworkWrap.sol";


contract GenerativeEggArworkTest is BaseTest {
    function testBorderWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 6; i++) {
            total += generativeEggArtwork.borderWeights(i);
        }

        assertEq(total, 1e18, "Sum of weights for Border should be 100%");
    }

    function testCardWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 13; i++) {
            total += generativeEggArtwork.cardWeights(i);
        }

        assertEq(total, 1e18, "Sum of weights for Card should be 100%");
    }

    function testShellWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 13; i++) {
            total += generativeEggArtwork.shellWeights(i);
        }

        assertEq(total, 1e18, "Sum of weights for Shell should be 100%");
    }

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

    // see: https://docs.google.com/spreadsheets/d/1GfbKWmx8OY62qvgbM4t-_acjdhXR5DMtY8zRxBPCn4g/edit#gid=297403569

    function testCardAffinityWeights() public {
        GenerativeEggArtworkWrap generativeEggArtwork = new GenerativeEggArtworkWrap();

        uint256[13] memory cardWeights;
        uint256[13] memory cardWeightsExpected;

        // Bronze
        cardWeights = generativeEggArtwork.getCardAffinityWeights(EggTraitWeights.BorderColor.Bronze);
        cardWeightsExpected = [uint256(113684e12), 113684e12, 113684e12, 104210e12, 104210e12, 66315e12, 66315e12, 66315e12, 66315e12, 10e16, 37894e12, 28421e12, 18947e12];
        _checkWeights(cardWeights, cardWeightsExpected);

        // Silver
        cardWeights = generativeEggArtwork.getCardAffinityWeights(EggTraitWeights.BorderColor.Silver);
        cardWeightsExpected = [uint256(115000e12), 115000e12, 115000e12, 105416e12, 105416e12, 67083e12, 67083e12, 67083e12, 67083e12, 47916e12, 8e16, 28750e12, 19166e12];
        _checkWeights(cardWeights, cardWeightsExpected);

        // Gold
        cardWeights = generativeEggArtwork.getCardAffinityWeights(EggTraitWeights.BorderColor.Gold);
        cardWeightsExpected = [uint256(116288e12), 116288e12, 116288e12, 106597e12, 106597e12, 67835e12, 67835e12, 67835e12, 67835e12, 48453e12, 38762e12, 6e16, 19381e12];
        _checkWeights(cardWeights, cardWeightsExpected);

        // Rainbow
        cardWeights = generativeEggArtwork.getCardAffinityWeights(EggTraitWeights.BorderColor.Rainbow);
        cardWeightsExpected = [uint256(117551e12), 117551e12, 117551e12, 107755e12, 107755e12, 68571e12, 68571e12, 68571e12, 68571e12, 48979e12, 39183e12, 29387e12, 4e16];
        _checkWeights(cardWeights, cardWeightsExpected);
    }

    function testShellAffinityWeights() public {
        GenerativeEggArtworkWrap generativeEggArtwork = new GenerativeEggArtworkWrap();

        uint256[13] memory shellWeights;
        uint256[13] memory shellWeightsExpected;

        // Bronze
        shellWeights = generativeEggArtwork.getShellAffinityWeights(EggTraitWeights.BorderColor.Bronze);
        shellWeightsExpected = [uint256(101081e12), 82702e12, 82702e12, 91891e12, 91891e12, 91891e12, 91891e12, 91891e12, 15e16, 55135e12, 36757e12, 22973e12, 9189e12];
        _checkWeights(shellWeights, shellWeightsExpected);

        // Silver
        shellWeights = generativeEggArtwork.getShellAffinityWeights(EggTraitWeights.BorderColor.Silver);
        shellWeightsExpected = [uint256(102979e12), 84255e12, 84255e12, 93617e12, 93617e12, 93617e12, 93617e12, 93617e12, 70213e12, 12e16, 37447e12, 23404e12, 9362e12];
        //_checkWeights(shellWeights, shellWeightsExpected);

        // Gold
        shellWeights = generativeEggArtwork.getShellAffinityWeights(EggTraitWeights.BorderColor.Gold);
        shellWeightsExpected = [uint256(105417e12), 86250e12, 86250e12, 95833e12, 95833e12, 95833e12, 95833e12, 95833e12, 71875e12, 57500e12, 8e16, 23958e12, 9583e12];
        _checkWeights(shellWeights, shellWeightsExpected);

        // Rainbow
        shellWeights = generativeEggArtwork.getShellAffinityWeights(EggTraitWeights.BorderColor.Rainbow);
        shellWeightsExpected = [uint256(107179e12), 87692e12, 87692e12, 97436e12, 97436e12, 97436e12, 97436e12, 97436e12, 73077e12, 58462e12, 38974e12, 5e16, 9744e12];
        _checkWeights(shellWeights, shellWeightsExpected);
    }

    function testGetBorderColor() public {
        GenerativeEggArtworkWrap generativeEggArtwork = new GenerativeEggArtworkWrap();

        // White
        assertEq(uint256(generativeEggArtwork.getBorderColor(0)), uint256(EggTraitWeights.BorderColor.White), "Border color should be white");
        assertEq(uint256(generativeEggArtwork.getBorderColor(29999999e10)), uint256(EggTraitWeights.BorderColor.White), "Border color should be white");

        // Black
        assertEq(uint256(generativeEggArtwork.getBorderColor(30e16)), uint256(EggTraitWeights.BorderColor.Black), "Border color should be black");
        assertEq(uint256(generativeEggArtwork.getBorderColor(59999999e10)), uint256(EggTraitWeights.BorderColor.Black), "Border color should be black");

        // Bronze
        assertEq(uint256(generativeEggArtwork.getBorderColor(60e16)), uint256(EggTraitWeights.BorderColor.Bronze), "Border color should be bronze");
        assertEq(uint256(generativeEggArtwork.getBorderColor(74999999e10)), uint256(EggTraitWeights.BorderColor.Bronze), "Border color should be bronze");

        // Silver
        assertEq(uint256(generativeEggArtwork.getBorderColor(75e16)), uint256(EggTraitWeights.BorderColor.Silver), "Border color should be silver");
        assertEq(uint256(generativeEggArtwork.getBorderColor(86999999e10)), uint256(EggTraitWeights.BorderColor.Silver), "Border color should be silver");

        // Gold
        assertEq(uint256(generativeEggArtwork.getBorderColor(87e16)), uint256(EggTraitWeights.BorderColor.Gold), "Border color should be gold");
        assertEq(uint256(generativeEggArtwork.getBorderColor(94999999e10)), uint256(EggTraitWeights.BorderColor.Gold), "Border color should be gold");

        // Rainbow
        assertEq(uint256(generativeEggArtwork.getBorderColor(95e16)), uint256(EggTraitWeights.BorderColor.Rainbow), "Border color should be rainbow");
        assertEq(uint256(generativeEggArtwork.getBorderColor(99999999e10)), uint256(EggTraitWeights.BorderColor.Rainbow), "Border color should be rainbow");
    }

    function testGetCardColor() public {
        GenerativeEggArtworkWrap generativeEggArtwork = new GenerativeEggArtworkWrap();

        // Border color non special

        // Red
        assertEq(
            uint256(generativeEggArtwork.getCardColor(0, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Red),
            "Card color should be red"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(11999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Red),
            "Card color should be red"
        );

        // Green
        assertEq(
            uint256(generativeEggArtwork.getCardColor(12e16, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Green),
            "Card color should be green"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(23999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Green),
            "Card color should be green"
        );

        // (...)
        // Gold
        assertEq(
            uint256(generativeEggArtwork.getCardColor(95e16, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Gold),
            "Card color should be gold"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(97999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Gold),
            "Card color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(generativeEggArtwork.getCardColor(98e16, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Rainbow),
            "Card color should be rainbow"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(99999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.CardColor.Rainbow),
            "Card color should be rainbow"
        );

        // (...)
        // Border color rainbow

        // Red
        assertEq(
            uint256(generativeEggArtwork.getCardColor(0, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Red),
            "Card color should be red"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(11755102e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Red),
            "Card color should be red"
        );

        // Green
        assertEq(
            uint256(generativeEggArtwork.getCardColor(11755103e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Green),
            "Card color should be green"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(23510204e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Green),
            "Card color should be green"
        );

        // (...)
        // Gold
        assertEq(
            uint256(generativeEggArtwork.getCardColor(93061225e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Gold),
            "Card color should be gold"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(95999999e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Gold),
            "Card color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(generativeEggArtwork.getCardColor(96e16, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Rainbow),
            "Card color should be rainbow"
        );
        assertEq(
            uint256(generativeEggArtwork.getCardColor(99999999e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.CardColor.Rainbow),
            "Card color should be rainbow"
        );
    }

    function testGetShellColor() public {
        GenerativeEggArtworkWrap generativeEggArtwork = new GenerativeEggArtworkWrap();

        // Border color non special

        // OffWhite
        assertEq(
            uint256(generativeEggArtwork.getShellColor(0, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Shell color should be OffWhite"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(10999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Shell color should be OffWhite"
        );

        // LightBlue
        assertEq(
            uint256(generativeEggArtwork.getShellColor(11e16, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Shell color should be LightBlue"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(19999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Shell color should be LightBlue"
        );

        // (...)
        // Gold
        assertEq(
            uint256(generativeEggArtwork.getShellColor(925e15, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Shell color should be gold"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(95599999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Shell color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(generativeEggArtwork.getShellColor(965e15, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Shell color should be rainbow"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(98999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Shell color should be rainbow"
        );

        // Luminous
        assertEq(
            uint256(generativeEggArtwork.getShellColor(99e16, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Shell color should be luminous"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(99999999e10, EggTraitWeights.BorderColor.White)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Shell color should be luminous"
        );

        // (...)
        // Border color rainbow

        // OffWhite
        assertEq(
            uint256(generativeEggArtwork.getShellColor(0, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Shell color should be OffWhite"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(10717948e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.OffWhite),
            "Shell color should be OffWhite"
        );

        // LightBlue
        assertEq(
            uint256(generativeEggArtwork.getShellColor(10717949e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Shell color should be LightBlue"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(19487179e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.LightBlue),
            "Shell color should be LightBlue"
        );

        // (...)
        // Gold
        assertEq(
            uint256(generativeEggArtwork.getShellColor(90128206e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Shell color should be gold"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(94025641e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Gold),
            "Shell color should be gold"
        );

        // Rainbow
        assertEq(
            uint256(generativeEggArtwork.getShellColor(94025642e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Shell color should be rainbow l2"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(99025640e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Rainbow),
            "Shell color should be rainbow"
        );

        // Luminous
        assertEq(
            uint256(generativeEggArtwork.getShellColor(99025641e16, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Shell color should be luminous"
        );
        assertEq(
            uint256(generativeEggArtwork.getShellColor(99999999e10, EggTraitWeights.BorderColor.Rainbow)),
            uint256(EggTraitWeights.ShellColor.Luminous),
            "Shell color should be luminous"
        );
    }
}
