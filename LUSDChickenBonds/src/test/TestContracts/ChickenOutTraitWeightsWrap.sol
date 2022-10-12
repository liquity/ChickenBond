// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "../../NFTArtwork/ChickenOutTraitWeights.sol";


contract ChickenOutTraitWeightsWrap is ChickenOutTraitWeights {
    function getChickenColor(uint256 rand, ShellColor shellColor) external view returns (ShellColor) {
        return _getChickenColor(rand, shellColor);
    }
}
