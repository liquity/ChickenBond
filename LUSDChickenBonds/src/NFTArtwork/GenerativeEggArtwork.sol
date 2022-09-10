// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "datetime/contracts/BokkyPooBahsDateTimeLibrary.sol";
import "../Interfaces/IBondNFTArtwork.sol";
import "../Interfaces/IChickenBondManager.sol";
import "./EggTraitWeights.sol";


interface IChickenBondManagerGetter {
    function chickenBondManager() external view returns (IChickenBondManager);
}

contract GenerativeEggArtwork is EggTraitWeights, IBondNFTArtwork {
    using Strings for uint256;

    enum EggSize {
        Tiny,
        Small,
        Normal,
        Big
    }

    struct BondData {
        uint256 tokenID;
        uint256 lusdAmount;
        uint256 claimedBLUSD;
        uint256 startTime;
        uint256 endTime;
        uint80 initialHalfDna;
        uint80 finalHalfDna;
        uint8 status;

        // Attributes derived from the DNA
        BorderColor borderColor;
        CardColor cardColor;
        ShellColor shellColor;
        EggSize eggSize;

        // Further data derived from the attributes
        string solidBorderColor;
        string solidCardColor;
        string solidShellColor;
        bool isBlendedShell;
        bool hasCardGradient;
        string[2] cardGradient;
    }

    function _getEggSize(uint256 lusdAmount) internal pure returns (EggSize) {
        return (
            lusdAmount <    1_000e18 ?  EggSize.Tiny   :
            lusdAmount <   10_000e18 ?  EggSize.Small  :
            lusdAmount <  100_000e18 ?  EggSize.Normal :
         /* lusdAmount >= 100_000e18 */ EggSize.Big
        );
    }

    function _cutDNA(uint256 dna, uint8 startBit, uint8 numBits) internal pure returns (uint256) {
        uint256 ceil = 1 << numBits;
        uint256 bits = (dna >> startBit) & (ceil - 1);

        return bits * 1e18 / ceil; // scaled to [0,1) range
    }

    function _calcAttributes(BondData memory _bondData) internal view {
        uint80 dna = _bondData.initialHalfDna;

        _bondData.borderColor = _getBorderColor(_cutDNA(dna,  0, 26));
        _bondData.cardColor   = _getCardColor  (_cutDNA(dna, 26, 27), _bondData.borderColor);
        _bondData.shellColor  = _getShellColor (_cutDNA(dna, 53, 27), _bondData.borderColor);

        _bondData.eggSize = _getEggSize(_bondData.lusdAmount);
    }

    function _getSolidBorderColor(BorderColor _color) internal pure returns (string memory) {
        return (
            _color == BorderColor.White  ?    "#fff" :
            _color == BorderColor.Black  ?    "#000" :
            _color == BorderColor.Bronze ? "#cd7f32" :
            _color == BorderColor.Silver ? "#c0c0c0" :
            _color == BorderColor.Gold   ? "#ffd700" : ""
        );
    }

    function _getSolidCardColor(CardColor _color) internal pure returns (string memory) {
        return (
            _color == CardColor.Red    ? "#ea394e" :
            _color == CardColor.Green  ? "#5caa4b" :
            _color == CardColor.Blue   ? "#008bf7" :
            _color == CardColor.Purple ? "#9d34e8" :
            _color == CardColor.Pink   ? "#e54cae" : ""
        );
    }

    function _getSolidShellColor(ShellColor _shell, CardColor _card) internal pure returns (string memory) {
        return (
            _shell == ShellColor.OffWhite      ? "#fff1cb" :
            _shell == ShellColor.LightBlue     ? "#e5eff9" :
            _shell == ShellColor.DarkerBlue    ? "#aedfe2" :
            _shell == ShellColor.LighterOrange ? "#f6dac9" :
            _shell == ShellColor.LightOrange   ? "#f8d1b2" :
            _shell == ShellColor.DarkerOrange  ? "#fcba92" :
            _shell == ShellColor.LightGreen    ? "#c5e8d6" :
            _shell == ShellColor.DarkerGreen   ? "#e5daaa" :
            _shell == ShellColor.Bronze        ? "#cd7f32" :
            _shell == ShellColor.Silver        ? "#c0c0c0" :
            _shell == ShellColor.Gold          ? "#ffd700" :

            _shell == ShellColor.Luminous ? (
                _card == CardColor.Bronze ? "#cd7f32" :
                _card == CardColor.Silver ? "#c0c0c0" :
                _card == CardColor.Gold   ? "#ffd700" : ""
            ) : ""
        );
    }

    function _getCardGradient(CardColor _color) internal pure returns (bool, string[2] memory) {
        return (
            _color == CardColor.YellowPink ? (true, ["#ffd200", "#ff0087"]) :
            _color == CardColor.BlueGreen  ? (true, ["#008bf7", "#58b448"]) :
            _color == CardColor.PinkBlue   ? (true, ["#f900bd", "#00a7f6"]) :
            _color == CardColor.RedPurple  ? (true, ["#ea394e", "#9d34e8"]) :
            _color == CardColor.Bronze     ? (true, ["#804a00", "#cd7b26"]) :
            _color == CardColor.Silver     ? (true, ["#71706e", "#b6b6b6"]) :
            _color == CardColor.Gold       ? (true, ["#aa6c39", "#ffae00"]) : (false, ["", ""])
        );
    }

    function _calcDerivedData(BondData memory _bondData) internal pure {
        _bondData.solidBorderColor = _getSolidBorderColor(_bondData.borderColor);
        _bondData.solidCardColor = _getSolidCardColor(_bondData.cardColor);
        _bondData.solidShellColor = _getSolidShellColor(_bondData.shellColor, _bondData.cardColor);

        _bondData.isBlendedShell = _bondData.shellColor == ShellColor.Luminous && !(
            _bondData.cardColor == CardColor.Bronze ||
            _bondData.cardColor == CardColor.Silver ||
            _bondData.cardColor == CardColor.Gold   ||
            _bondData.cardColor == CardColor.Rainbow
        );

        (_bondData.hasCardGradient, _bondData.cardGradient) = _getCardGradient(_bondData.cardColor);
    }

    function tokenURI(uint256 _tokenID, IBondNFT.BondExtraData calldata _bondExtraData) external view returns (string memory) {
        IChickenBondManager chickenBondManager =
            IChickenBondManagerGetter(msg.sender).chickenBondManager();

        BondData memory bondData;
        bondData.tokenID = _tokenID;
        (
            bondData.lusdAmount,
            bondData.claimedBLUSD,
            bondData.startTime,
            bondData.endTime,
            bondData.status
        ) = chickenBondManager.getBondData(_tokenID);
        bondData.initialHalfDna = _bondExtraData.initialHalfDna;
        bondData.finalHalfDna = _bondExtraData.finalHalfDna;

        _calcAttributes(bondData);
        _calcDerivedData(bondData);

        return _getMetadataJSON(bondData);
    }

    // function testTokenURI(
    //     uint256 _tokenID,
    //     uint256 _lusdAmount,
    //     uint256 _startTime,
    //     BorderColor _borderColor,
    //     CardColor _cardColor,
    //     ShellColor _shellColor,
    //     EggSize _eggSize
    // )
    //     external
    //     pure
    //     returns (string memory)
    // {
    //     BondData memory bondData;
    //     bondData.tokenID = _tokenID;
    //     bondData.lusdAmount = _lusdAmount;
    //     bondData.startTime = _startTime;
        
    //     bondData.borderColor = _borderColor;
    //     bondData.cardColor = _cardColor;
    //     bondData.shellColor = _shellColor;
    //     bondData.eggSize = _eggSize;

    //     _calcDerivedData(bondData);

    //     return _getMetadataJSON(bondData);
    // }

    function _getMetadataCardAttributes(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '{"trait_type":"Border","value":"', _getBorderValue(_bondData.borderColor), '"},',
            '{"trait_type":"Card","value":"', _getCardValue(_bondData.cardColor), '"},',
            '{"trait_type":"Shell","value":"', _getShellValue(_bondData.shellColor), '"},',
            '{"trait_type":"Size","value":"', _getSizeValue(_bondData.eggSize), '"}'
        );
    }

    function _getMetadataAttributes(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '"attributes":[',
                '{"display_type":"date","trait_type":"Created","value":', _bondData.startTime.toString(), '},',
                '{"display_type":"number","trait_type":"Bond Amount","value":', _formatDecimal(_bondData.lusdAmount), '},',
                '{"trait_type":"Bond Status","value":"', _getBondStatusValue(IChickenBondManager.BondStatus(_bondData.status)), '"},',
                _getMetadataCardAttributes(_bondData),
            ']'
        );
    }

    function _getMetadataJSON(BondData memory _bondData) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    abi.encodePacked(
                        '{',
                            '"name":"LUSD Chicken #', _bondData.tokenID.toString(), '",',
                            '"description":"LUSD Chicken Bonds",',
                            '"image":"data:image/svg+xml;base64,', Base64.encode(_getSVG(_bondData)), '",',
                            '"background_color":"0b112f",',
                            _getMetadataAttributes(_bondData),
                        '}'
                    )
                )
            )
        );
    }

    function _getBondStatusValue(IChickenBondManager.BondStatus _status) internal pure returns (string memory) {
        return (
            _status == IChickenBondManager.BondStatus.chickenedIn  ? "Chickened In"  :
            _status == IChickenBondManager.BondStatus.chickenedOut ? "Chickened Out" :
            _status == IChickenBondManager.BondStatus.active       ? "Active"        : ""
        );
    }

    function _getBorderValue(BorderColor _border) internal pure returns (string memory) {
        return (
            _border == BorderColor.White    ? "White"   :
            _border == BorderColor.Black    ? "Black"   :
            _border == BorderColor.Bronze   ? "Bronze"  :
            _border == BorderColor.Silver   ? "Silver"  :
            _border == BorderColor.Gold     ? "Gold"    :
            _border == BorderColor.Rainbow  ? "Rainbow" : ""
        );
    }

    function _getCardValue(CardColor _card) internal pure returns (string memory) {
        return (
            _card == CardColor.Red        ? "Red"         :
            _card == CardColor.Green      ? "Green"       :
            _card == CardColor.Blue       ? "Blue"        :
            _card == CardColor.Purple     ? "Purple"      :
            _card == CardColor.Pink       ? "Pink"        :
            _card == CardColor.YellowPink ? "Yellow-Pink" :
            _card == CardColor.BlueGreen  ? "Blue-Green"  :
            _card == CardColor.PinkBlue   ? "Pink-Blue"   :
            _card == CardColor.RedPurple  ? "Red-Purple"  :
            _card == CardColor.Bronze     ? "Bronze"      :
            _card == CardColor.Silver     ? "Silver"      :
            _card == CardColor.Gold       ? "Gold"        :
            _card == CardColor.Rainbow    ? "Rainbow"     : ""
        );
    }

    function _getShellValue(ShellColor _shell) internal pure returns (string memory) {
        return (
            _shell == ShellColor.OffWhite      ? "Off-White"      :
            _shell == ShellColor.LightBlue     ? "Light Blue"     :
            _shell == ShellColor.DarkerBlue    ? "Darker Blue"    :
            _shell == ShellColor.LighterOrange ? "Lighter Orange" :
            _shell == ShellColor.LightOrange   ? "Light Orange"   :
            _shell == ShellColor.DarkerOrange  ? "Darker Orange"  :
            _shell == ShellColor.LightGreen    ? "Light Green"    :
            _shell == ShellColor.DarkerGreen   ? "Darker Green"   :
            _shell == ShellColor.Bronze        ? "Bronze"         :
            _shell == ShellColor.Silver        ? "Silver"         :
            _shell == ShellColor.Gold          ? "Gold"           :
            _shell == ShellColor.Rainbow       ? "Rainbow"        :
            _shell == ShellColor.Luminous      ? "Luminous"       : ""
        );
    }

    function _getSizeValue(EggSize _size) internal pure returns (string memory) {
        return (
            _size == EggSize.Tiny   ? "Tiny"   :
            _size == EggSize.Small  ? "Small"  :
            _size == EggSize.Normal ? "Normal" :
            _size == EggSize.Big    ? "Big"    : ""
        );
    }

    function _getMonthString(uint256 _month) internal pure returns (string memory) {
        return (
            _month ==  1 ? "JANUARY"   :
            _month ==  2 ? "FEBRUARY"  :
            _month ==  3 ? "MARCH"     :
            _month ==  4 ? "APRIL"     :
            _month ==  5 ? "MAY"       :
            _month ==  6 ? "JUNE"      :
            _month ==  7 ? "JULY"      :
            _month ==  8 ? "AUGUST"    :
            _month ==  9 ? "SEPTEMBER" :
            _month == 10 ? "OCTOBER"   :
            _month == 11 ? "NOVEMBER"  :
            _month == 12 ? "DECEMBER"  : ""
        );
    }

    function _formatDate(uint256 timestamp) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _getMonthString(DateTime.getMonth(timestamp)),
            ' ',
            DateTime.getDay(timestamp).toString(),
            ', ',
            DateTime.getYear(timestamp).toString()
        );
    }

    function _formatDecimal(uint256 decimal) internal pure returns (string memory) {
        return ((decimal + 0.5e18) / 1e18).toString();
    }

    function _getSVGStyle(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                '#cb-egg-', _bondData.tokenID.toString(), ' .cb-egg path {',
                    'animation: shake 3s infinite ease-out;',
                    'transform-origin: 50%;',
                '}',

                '@keyframes shake {',
                    '0% { transform: rotate(0deg); }',
                    '65% { transform: rotate(0deg); }',
                    '70% { transform: rotate(3deg); }',
                    '75% { transform: rotate(0deg); }',
                    '80% { transform: rotate(-3deg); }',
                    '85% { transform: rotate(0deg); }',
                    '90% { transform: rotate(3deg); }',
                    '100% { transform: rotate(0deg); }',
                '}',
            '</style>'
        );
    }

    function _getSVGDefCardDiagonalGradient(BondData memory _bondData) internal pure returns (bytes memory) {
        if (!_bondData.hasCardGradient) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _bondData.tokenID.toString(), '-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-color="', _bondData.cardGradient[0], '"/>',
                '<stop offset="1" stop-color="', _bondData.cardGradient[1], '"/>',
            '</linearGradient>'
        );
    }

    function _getSVGDefCardRadialGradient(BondData memory _bondData) internal pure returns (bytes memory) {
        if (_bondData.shellColor != ShellColor.Luminous) {
            return bytes('');
        }

        return abi.encodePacked(
            '<radialGradient id="cb-egg-', _bondData.tokenID.toString(), '-card-radial-gradient" cx="50%" cy="45%" r="38%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-opacity="0"/>',
                '<stop offset="0.25" stop-opacity="0"/>',
                '<stop offset="1" stop-color="#000" stop-opacity="1"/>',
            '</radialGradient>'
        );
    }

    function _getSVGDefCardRainbowGradient(BondData memory _bondData) internal pure returns (bytes memory) {
        if (_bondData.cardColor != CardColor.Rainbow && _bondData.borderColor != BorderColor.Rainbow) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _bondData.tokenID.toString(), '-card-rainbow-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-color="#93278f"/>',
                '<stop offset="0.2" stop-color="#662d91"/>',
                '<stop offset="0.4" stop-color="#3395d4"/>',
                '<stop offset="0.5" stop-color="#39b54a"/>',
                '<stop offset="0.6" stop-color="#fcee21"/>',
                '<stop offset="0.8" stop-color="#fbb03b"/>',
                '<stop offset="1" stop-color="#ed1c24"/>',
            '</linearGradient>'
        );
    }

    function _getSVGDefShellRainbowGradient(BondData memory _bondData) internal pure returns (bytes memory) {
        if (
            _bondData.shellColor != ShellColor.Rainbow &&
            !(_bondData.shellColor == ShellColor.Luminous && _bondData.cardColor == CardColor.Rainbow)
        ) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _bondData.tokenID.toString(), '-shell-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-color="#3fa9f5"/>',
                '<stop offset="0.38" stop-color="#39b54a"/>',
                '<stop offset="0.82" stop-color="#fcee21"/>',
                '<stop offset="1" stop-color="#fbb03b"/>',
            '</linearGradient>'
        );
    }

    function _getSVGDefs(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<defs>',
                _getSVGDefCardDiagonalGradient(_bondData),
                _getSVGDefCardRadialGradient(_bondData),
                _getSVGDefCardRainbowGradient(_bondData),
                _getSVGDefShellRainbowGradient(_bondData),
            '</defs>'
        );
    }

    function _getSVGBorder(BondData memory _bondData) internal pure returns (bytes memory) {
        if (_bondData.shellColor == ShellColor.Luminous && _bondData.borderColor == BorderColor.Black) {
            // We will use the black radial gradient as border (covering the entire card)
            return bytes('');
        }

        return abi.encodePacked(
            '<rect ',
                _bondData.borderColor == BorderColor.Rainbow
                    ? abi.encodePacked('style="fill: url(#cb-egg-', _bondData.tokenID.toString(), '-card-rainbow-gradient)" ')
                    : abi.encodePacked('fill="', _bondData.solidBorderColor, '" '),
                'width="100%" height="100%" rx="37.5"',
            '/>'
        );
    }

    function _getSVGCard(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _bondData.cardColor == CardColor.Rainbow && _bondData.borderColor == BorderColor.Rainbow
                ? bytes('') // Rainbow gradient already placed by border
                : abi.encodePacked(
                    '<rect ',
                        _bondData.cardColor == CardColor.Rainbow
                            ? abi.encodePacked('style="fill: url(#cb-egg-', _bondData.tokenID.toString(), '-card-rainbow-gradient)" ')
                            : _bondData.hasCardGradient
                            ? abi.encodePacked('style="fill: url(#cb-egg-', _bondData.tokenID.toString(), '-card-diagonal-gradient)" ')
                            : abi.encodePacked('fill="', _bondData.solidCardColor, '" '),
                        'x="30" y="30" width="690" height="990" rx="37.5"',
                    '/>'
                ),

            _bondData.cardColor == CardColor.Rainbow
                ? '<rect fill="#000" opacity="0.05" x="30" y="30" width="690" height="990" rx="37.5"/>'
                : ''
        );
    }

    function _getSVGCardRadialGradient(BondData memory _bondData) internal pure returns (bytes memory) {
        if (_bondData.shellColor != ShellColor.Luminous) {
            return bytes('');
        }

        return abi.encodePacked(
            '<rect ',
                'style="fill: url(#cb-egg-', _bondData.tokenID.toString(), '-card-radial-gradient); mix-blend-mode: hard-light" ',
                _bondData.borderColor == BorderColor.Black
                    ? 'width="100%" height="100%" '
                    : 'x="30" y="30" width="690" height="990" ',
                'rx="37.5"',
            '/>'
        );
    }

    function _getSVGShadowBelowEgg(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<ellipse ',
                _bondData.shellColor == ShellColor.Luminous ? 'style="mix-blend-mode: luminosity" ' : '',
                'fill="#0a102e" ',
                _bondData.eggSize == EggSize.Tiny
                    ? 'cx="375" cy="560.25" rx="60" ry="11.4" '
                    : _bondData.eggSize == EggSize.Small
                    ? 'cx="375" cy="589.5" rx="80" ry="15.2" '
                    : _bondData.eggSize == EggSize.Big
                    ? 'cx="375" cy="648" rx="120" ry="22.8" '
                    // _bondData.eggSize == EggSize.Normal
                    : 'cx="375" cy="618.75" rx="100" ry="19" ',
            '/>'
        );
    }

    function _getSVGShellPathData(BondData memory _bondData) internal pure returns (string memory) {
        return _bondData.eggSize == EggSize.Tiny
            ? 'M293.86 478.12c0 45.36 36.4 82.13 81.29 82.13s81.29-36.77 81.29-82.13S420.05 365.85 375.15 365.85C332.74 365.85 293.86 432.76 293.86 478.12Z'
            : _bondData.eggSize == EggSize.Small
            ? 'M266.81 480c0 60.48 48.53 109.5 108.39 109.5s108.39-49.02 108.39-109.5S435.06 330.3 375.2 330.3C318.65 330.3 266.81 419.52 266.81 480Z'
            : _bondData.eggSize == EggSize.Big
            ? 'M212.71 483.74c0 90.72 72.79 164.26 162.59 164.26s162.59-73.54 162.59-164.26S465.1 259.2 375.3 259.2C290.47 259.2 212.71 393.02 212.71 483.74Z'
            // _bondData.eggSize == EggSize.Normal
            : 'M239.76 481.87c0 75.6 60.66 136.88 135.49 136.88s135.49-61.28 135.49-136.88S450.08 294.75 375.25 294.75C304.56 294.75 239.76 406.27 239.76 481.87Z';
    }

    function _getSVGHighlightPathData(BondData memory _bondData) internal pure returns (string memory) {
        return _bondData.eggSize == EggSize.Tiny
            ? 'M328.96 409.4c-6 13.59-5.48 29.53 3.25 36.11 9.76 7.35 23.89 9 36.98-3.13 12.57-11.66 23.48-43.94 1.24-55.5C358.25 380.55 335.59 394.35 328.96 409.4Z'
            : _bondData.eggSize == EggSize.Small
            ? 'M313.61 388.36c-8 18.12-7.3 39.38 4.33 48.16 13.01 9.8 31.85 12 49.31-4.18 16.76-15.54 31.3-58.59 1.65-74C352.66 349.9 322.45 368.3 313.61 388.36Z'
            : _bondData.eggSize == EggSize.Big
            ? 'M282.91 346.3c-12 27.18-10.96 59.06 6.51 72.22 19.51 14.7 47.77 18 73.95-6.26 25.14-23.32 46.96-87.89 2.49-111C341.5 288.6 296.17 316.2 282.91 346.3Z'
            // _bondData.eggSize == EggSize.Normal
            : 'M298.26 367.33c-10 22.65-9.13 49.22 5.42 60.19 16.26 12.25 39.81 15 61.63-5.22 20.95-19.43 39.13-73.24 2.07-92.5C347.08 319.25 309.31 342.25 298.26 367.33Z';
    }

    function _getSVGSelfShadowPathData(BondData memory _bondData) internal pure returns (string memory) {
        return _bondData.eggSize == EggSize.Tiny
            ? 'M416.17 385.02c11.94 20.92 19.15 45.35 19.14 65.52 0 45.36-36.4 82.13-81.3 82.13a80.45 80.45 0 0 1-52.52-19.45C314.52 541.03 342.54 560.27 375 560.27c44.9 0 81.3-36.77 81.3-82.13C456.31 447.95 440.18 408.22 416.17 385.02Z'
            : _bondData.eggSize == EggSize.Small
            ? 'M429.89 355.86c15.92 27.89 25.53 60.46 25.53 87.36 0 60.48-48.54 109.5-108.4 109.5a107.26 107.26 0 0 1-70.03-25.92C294.36 563.88 331.72 589.52 375 589.52c59.86 0 108.4-49.02 108.4-109.5C483.42 439.76 461.91 386.8 429.89 355.86Z'
            : _bondData.eggSize == EggSize.Big
            ? 'M457.33 297.54c23.88 41.83 38.29 90.7 38.29 131.04 0 90.72-72.8 164.26-162.6 164.26a160.9 160.9 0 0 1-105.03-38.9C254.04 609.56 310.08 648.04 375 648.04c89.8 0 162.6-73.54 162.6-164.26C537.62 423.4 505.37 343.94 457.33 297.54Z'
            // _bondData.eggSize == EggSize.Normal
            : 'M443.61 326.7c19.9 34.86 31.91 75.58 31.91 109.2 0 75.6-60.67 136.88-135.5 136.88a134.08 134.08 0 0 1-87.53-32.41C274.2 586.72 320.9 618.78 375 618.78c74.83 0 135.5-61.28 135.5-136.88C510.52 431.58 483.64 365.37 443.61 326.7Z';
    }

    function _getSVGEgg(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<g class="cb-egg">',
                '<path ',
                    _bondData.shellColor == ShellColor.Rainbow ||
                    _bondData.shellColor == ShellColor.Luminous && _bondData.cardColor == CardColor.Rainbow
                        ? abi.encodePacked('style="fill: url(#cb-egg-', _bondData.tokenID.toString(), '-shell-rainbow-gradient)" ')
                        : _bondData.isBlendedShell
                        ? bytes('style="mix-blend-mode: luminosity" fill="#e5eff9" ')
                        : abi.encodePacked('fill="', _bondData.solidShellColor, '" '),
                    'd="', _getSVGShellPathData(_bondData), '"',
                '/>',

                '<path style="mix-blend-mode: soft-light" fill="#fff" d="', _getSVGHighlightPathData(_bondData), '"/>',
                '<path style="mix-blend-mode: soft-light" fill="#000" d="', _getSVGSelfShadowPathData(_bondData), '"/>',
            '</g>'
        );
    }

    function _getSVGText(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="72px" font-weight="800" text-anchor="middle" x="50%" y="14%">LUSD</text>',

            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="19%">',
                'ID: ', _bondData.tokenID.toString(),
            '</text>',

            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="40px" font-weight="800" text-anchor="middle" x="50%" y="72%">BOND AMOUNT</text>',

            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="64px" font-weight="800" text-anchor="middle" x="50%" y="81%">',
                _formatDecimal(_bondData.lusdAmount),
            '</text>',

            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="91%" opacity="0.6">',
                _formatDate(_bondData.startTime),
            '</text>'
        );
    }

    function _getSVG(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGStyle(_bondData),
                _getSVGDefs(_bondData),

                '<g id="cb-egg-', _bondData.tokenID.toString(), '">',
                    _getSVGBorder(_bondData),
                    _getSVGCard(_bondData),
                    _getSVGCardRadialGradient(_bondData),
                    _getSVGShadowBelowEgg(_bondData),
                    _getSVGEgg(_bondData),
                    _getSVGText(_bondData),
                '</g>',
            '</svg>'
        );
    }
}
