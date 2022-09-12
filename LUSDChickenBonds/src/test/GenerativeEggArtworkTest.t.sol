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
    // TODO: add checks for certain `rand` values for `_getBorderColor`, `_getCardColor` and `_getShellColor`
}
