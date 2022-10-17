// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./EggTraitWeights.sol";

struct ChickenInData {
    // Attributes derived from the DNA
    EggTraitWeights.ShellColor chickenColor;
    uint8 comb;
    uint8 beak;
    uint8 tail;
    uint8 wing;

    // Further data derived from the attributes
    bool darkMode;
    bool hasLQTY;
    bool hasTrove;
    bool hasLlama;
    bool isRainbow;
    bytes caruncleStyle;
    bytes beakStyle;
    bytes legStyle;
    bytes chickenStyle;
    bytes bodyShadeStyle;
    bytes cheekStyle;
    bytes wingShadeStyle;
    bytes wingTipShadeStyle;
}

