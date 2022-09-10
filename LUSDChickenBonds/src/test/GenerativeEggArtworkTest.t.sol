pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "../NFTArtwork/GenerativeEggArtwork.sol";


contract GenerativeEggArworkTest is Test {
    function testBorderWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 6; i++) {
            total += generativeEggArtwork.borderWeights(i);
        }

        assertEq(total, 1e18, "Sum of weigths for Border should be 100%");
    }

    function testCardWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 13; i++) {
            total += generativeEggArtwork.cardWeights(i);
        }

        assertEq(total, 1e18, "Sum of weigths for Card should be 100%");
    }

    function testShellWeightsTotal() public {
        GenerativeEggArtwork generativeEggArtwork = new GenerativeEggArtwork();

        uint256 total;

        for (uint256 i = 0; i < 13; i++) {
            total += generativeEggArtwork.shellWeights(i);
        }

        assertEq(total, 1e18, "Sum of weigths for Shell should be 100%");
    }

    // TODO: add checks for certain `rand` values for `_getBorderColor`, `_getCardColor` and `_getShellColor`
}
