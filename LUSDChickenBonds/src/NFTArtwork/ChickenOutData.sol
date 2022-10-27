// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./EggTraitWeights.sol";

struct ChickenOutData {
    // Attributes derived from the DNA
    EggTraitWeights.ShellColor chickenColor;

    // Further data derived from the attributes
    bool darkMode;
    bytes chickenStyle;
    bytes shellStyle;
}
