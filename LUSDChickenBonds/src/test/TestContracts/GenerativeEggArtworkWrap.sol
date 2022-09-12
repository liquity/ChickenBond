// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "../../NFTArtwork/GenerativeEggArtwork.sol";


contract GenerativeEggArtworkWrap is GenerativeEggArtwork {
    function getCardAffinityWeights(BorderColor borderColor) external view returns (uint256[13] memory cardWeightsCached) {
        return _getCardAffinityWeights(borderColor);
    }

    function getShellAffinityWeights(BorderColor borderColor) external view returns (uint256[13] memory shellWeightsCached) {
        return _getShellAffinityWeights(borderColor);
    }
}
