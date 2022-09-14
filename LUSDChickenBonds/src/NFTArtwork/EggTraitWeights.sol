pragma solidity ^0.8.11;


contract EggTraitWeights {
    enum BorderColor {
        White,
        Black,
        Bronze,
        Silver,
        Gold,
        Rainbow
    }

    enum CardColor {
        Red,
        Green,
        Blue,
        Purple,
        Pink,
        YellowPink,
        BlueGreen,
        PinkBlue,
        RedPurple,
        Bronze,
        Silver,
        Gold,
        Rainbow
    }

    enum ShellColor {
        OffWhite,
        LightBlue,
        DarkerBlue,
        LighterOrange,
        LightOrange,
        DarkerOrange,
        LightGreen,
        DarkerGreen,
        Bronze,
        Silver,
        Gold,
        Rainbow,
        Luminous
    }

    uint256[6] public borderWeights = [30e16, 30e16, 15e16, 12e16, 8e16, 5e16];
    uint256[13] public cardWeights = [12e16, 12e16, 12e16, 11e16, 11e16, 7e16, 7e16, 7e16, 7e16, 5e16, 4e16, 3e16, 2e16];
    uint256[13] public shellWeights = [11e16, 9e16, 9e16, 10e16, 10e16, 10e16, 10e16, 10e16, 75e15, 6e16, 4e16, 25e15, 1e16];

    // Turn the pseudo-random number `rand` -- 18 digit FP in range [0,1) -- into a border color.
    function _getBorderColor(uint256 rand) internal view returns (BorderColor) {
        uint256 needle = borderWeights[uint256(BorderColor.White)];
        if (rand < needle) { return BorderColor.White; }
        needle += borderWeights[uint256(BorderColor.Black)];
        if (rand < needle) { return BorderColor.Black; }
        needle += borderWeights[uint256(BorderColor.Bronze)];
        if (rand < needle) { return BorderColor.Bronze; }
        needle += borderWeights[uint256(BorderColor.Silver)];
        if (rand < needle) { return BorderColor.Silver; }
        needle += borderWeights[uint256(BorderColor.Gold)];
        if (rand < needle) { return BorderColor.Gold; }
        return BorderColor.Rainbow;
    }

    function _getCardAffinityWeights(BorderColor borderColor) internal view returns (uint256[13] memory cardWeightsCached) {
        if (borderColor == BorderColor.Bronze ||
            borderColor == BorderColor.Silver ||
            borderColor == BorderColor.Gold   ||
            borderColor == BorderColor.Rainbow
        ) {
            uint256 selectedCardColor =
                borderColor == BorderColor.Bronze ? uint256(CardColor.Bronze) :
                borderColor == BorderColor.Silver ? uint256(CardColor.Silver) :
                borderColor == BorderColor.Gold ? uint256(CardColor.Gold) :
                uint256(CardColor.Rainbow);
            uint256 originalWeight = cardWeights[selectedCardColor];
            uint256 finalWeight = originalWeight * 2;
            // As we are going to duplicate the original weight of the selected color,
            // we reduce that extra amount from all other weights, proportionally,
            // so we keep the total of 100%
            for (uint256 i = 0; i < cardWeightsCached.length; i++) {
                cardWeightsCached[i] = cardWeights[i] * (1e18 - finalWeight) / (1e18 - originalWeight);
            }
            cardWeightsCached[selectedCardColor] = finalWeight;
        } else {
            for (uint256 i = 0; i < cardWeightsCached.length; i++) {
                cardWeightsCached[i] = cardWeights[i];
            }
        }
    }

    // Turn the pseudo-random number `rand` -- 18 digit FP in range [0,1) -- into a card color.
    function _getCardColor(uint256 rand, BorderColor borderColor) internal view returns (CardColor) {
        // first adjust weights for affinity
        uint256[13] memory cardWeightsCached = _getCardAffinityWeights(borderColor);

        // then compute color
        uint256 needle = cardWeightsCached[uint256(CardColor.Red)];
        if (rand < needle) { return CardColor.Red; }
        needle += cardWeightsCached[uint256(CardColor.Green)];
        if (rand < needle) { return CardColor.Green; }
        needle += cardWeightsCached[uint256(CardColor.Blue)];
        if (rand < needle) { return CardColor.Blue; }
        needle += cardWeightsCached[uint256(CardColor.Purple)];
        if (rand < needle) { return CardColor.Purple; }
        needle += cardWeightsCached[uint256(CardColor.Pink)];
        if (rand < needle) { return CardColor.Pink; }
        needle += cardWeightsCached[uint256(CardColor.YellowPink)];
        if (rand < needle) { return CardColor.YellowPink; }
        needle += cardWeightsCached[uint256(CardColor.BlueGreen)];
        if (rand < needle) { return CardColor.BlueGreen; }
        needle += cardWeightsCached[uint256(CardColor.PinkBlue)];
        if (rand < needle) { return CardColor.PinkBlue; }
        needle += cardWeightsCached[uint256(CardColor.RedPurple)];
        if (rand < needle) { return CardColor.RedPurple; }
        needle += cardWeightsCached[uint256(CardColor.Bronze)];
        if (rand < needle) { return CardColor.Bronze; }
        needle += cardWeightsCached[uint256(CardColor.Silver)];
        if (rand < needle) { return CardColor.Silver; }
        needle += cardWeightsCached[uint256(CardColor.Gold)];
        if (rand < needle) { return CardColor.Gold; }
        return CardColor.Rainbow;
    }

    function _getShellAffinityWeights(BorderColor borderColor) internal view returns (uint256[13] memory shellWeightsCached) {
        if (borderColor == BorderColor.Bronze ||
            borderColor == BorderColor.Silver ||
            borderColor == BorderColor.Gold   ||
            borderColor == BorderColor.Rainbow
        ) {
            uint256 selectedShellColor =
                borderColor == BorderColor.Bronze ? uint256(ShellColor.Bronze) :
                borderColor == BorderColor.Silver ? uint256(ShellColor.Silver) :
                borderColor == BorderColor.Gold ? uint256(ShellColor.Gold) :
                uint256(ShellColor.Rainbow);
            uint256 originalWeight = shellWeights[selectedShellColor];
            uint256 finalWeight = originalWeight * 2;
            // As we are going to duplicate the original weight of the selected color,
            // we reduce that extra amount from all other weights, proportionally,
            // so we keep the total of 100%
            for (uint256 i = 0; i < shellWeightsCached.length; i++) {
                shellWeightsCached[i] = shellWeights[i] * (1e18 - finalWeight) / (1e18 - originalWeight);
            }
            shellWeightsCached[selectedShellColor] = finalWeight;
        } else {
            for (uint256 i = 0; i < shellWeightsCached.length; i++) {
                shellWeightsCached[i] = shellWeights[i];
            }
        }
    }

    // Turn the pseudo-random number `rand` -- 18 digit FP in range [0,1) -- into a shell color.
    function _getShellColor(uint256 rand, BorderColor borderColor) internal view returns (ShellColor) {
        // first adjust weights for affinity
        uint256[13] memory shellWeightsCached = _getShellAffinityWeights(borderColor);

        // then compute color
        uint256 needle = shellWeightsCached[uint256(ShellColor.OffWhite)];
        if (rand < needle) { return ShellColor.OffWhite; }
        needle += shellWeightsCached[uint256(ShellColor.LightBlue)];
        if (rand < needle) { return ShellColor.LightBlue; }
        needle += shellWeightsCached[uint256(ShellColor.DarkerBlue)];
        if (rand < needle) { return ShellColor.DarkerBlue; }
        needle += shellWeightsCached[uint256(ShellColor.LighterOrange)];
        if (rand < needle) { return ShellColor.LighterOrange; }
        needle += shellWeightsCached[uint256(ShellColor.LightOrange)];
        if (rand < needle) { return ShellColor.LightOrange; }
        needle += shellWeightsCached[uint256(ShellColor.DarkerOrange)];
        if (rand < needle) { return ShellColor.DarkerOrange; }
        needle += shellWeightsCached[uint256(ShellColor.LightGreen)];
        if (rand < needle) { return ShellColor.LightGreen; }
        needle += shellWeightsCached[uint256(ShellColor.DarkerGreen)];
        if (rand < needle) { return ShellColor.DarkerGreen; }
        needle += shellWeightsCached[uint256(ShellColor.Bronze)];
        if (rand < needle) { return ShellColor.Bronze; }
        needle += shellWeightsCached[uint256(ShellColor.Silver)];
        if (rand < needle) { return ShellColor.Silver; }
        needle += shellWeightsCached[uint256(ShellColor.Gold)];
        if (rand < needle) { return ShellColor.Gold; }
        needle += shellWeightsCached[uint256(ShellColor.Rainbow)];
        if (rand < needle) { return ShellColor.Rainbow; }
        return ShellColor.Luminous;
    }
}
