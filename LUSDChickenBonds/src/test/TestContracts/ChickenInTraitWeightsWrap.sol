// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "../../NFTArtwork/ChickenInTraitWeights.sol";


contract ChickenInTraitWeightsWrap is ChickenInTraitWeights {
    function getChickenColor(uint256 rand, ShellColor shellColor, uint256 troveFactor) external view returns (ShellColor) {
        return _getChickenColor(rand, shellColor, troveFactor);
    }

    function getChickenTrait9(uint256 rand, uint256 troveFactor) external pure returns (uint8) {
        return _getChickenTrait9(rand, troveFactor);
    }

    function getChickenBeak(uint256 rand, uint256 troveFactor) external pure returns (uint8) {
        return _getChickenBeak(rand, troveFactor);
    }

    function getChickenWing(uint256 rand, uint256 troveFactor) external pure returns (uint8) {
        return _getChickenWing(rand, troveFactor);
    }
}
