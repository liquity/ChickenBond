// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";

abstract contract ChickenOutBase is BondNFTArtworkBase {
    struct ChickenOutData {
        // Attributes derived from the DNA
        ShellColor chickenColor;

        // Further data derived from the attributes
        bool darkMode;
        bytes chickenStyle;
        bytes shellStyle;
    }
}
