// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "datetime/contracts/BokkyPooBahsDateTimeLibrary.sol";

import "../Interfaces/IBondNFTArtwork.sol";
import "../Interfaces/IChickenBondManager.sol";
import { IChickenBondManagerGetter } from "./BondNFTArtworkSwitcher.sol";
import "./EggTraitWeights.sol";
import "./CommonData.sol";

function _cutDNA(uint256 dna, uint8 startBit, uint8 numBits) pure returns (uint256) {
    uint256 ceil = 1 << numBits;
    uint256 bits = (dna >> startBit) & (ceil - 1);

    return bits * 1e18 / ceil; // scaled to [0,1) range
}

contract BondNFTArtworkCommon is EggTraitWeights {
    using Strings for uint256;

    ////////////////////////
    // External functions //
    ////////////////////////

    function calcData(CommonData memory _data) external view returns (CommonData memory) {
        _calcAttributes(_data);
        _calcDerivedData(_data);

        return _data;
    }

    function getMetadataJSON(
        CommonData calldata _data,
        bytes calldata _svg,
        bytes calldata _extraAttributes
    )
        external
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    abi.encodePacked(
                        '{',
                            '"name":"LUSD Chicken #', _data.tokenIDString, '",',
                            '"description":"LUSD Chicken Bonds",',
                            '"image":"data:image/svg+xml;base64,', Base64.encode(_svg), '",',
                            '"background_color":"0b112f",',
                            _getMetadataAttributes(_data, _extraAttributes),
                        '}'
                    )
                )
            )
        );
    }

    function getSVGBaseDefs(CommonData calldata _data, bool _darkMode)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGDefCardDiagonalGradient(_data),
            _getSVGDefCardRainbowGradient(_data),
            _darkMode ? _getSVGDefCardRadialGradient(_data) : bytes('')
        );
    }

    function getSVGBase(CommonData calldata _data, string memory _subtitle, bool _darkMode)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGBorder(_data, _darkMode),
            _getSVGCard(_data),
            _darkMode ? _getSVGCardRadialGradient(_data) : bytes(''),
            _getSVGText(_data, _subtitle)
        );
    }

    ///////////////////////
    // Private functions //
    ///////////////////////

    function _getSize(uint256 lusdAmount) private pure returns (Size) {
        return (
            lusdAmount <    1_000e18 ?  Size.Tiny   :
            lusdAmount <   10_000e18 ?  Size.Small  :
            lusdAmount <  100_000e18 ?  Size.Normal :
         /* lusdAmount >= 100_000e18 */ Size.Big
        );
    }

    function _calcAttributes(CommonData memory _data) private view {
        uint80 dna = _data.initialHalfDna;

        _data.borderColor = _getBorderColor(_cutDNA(dna,  0, 26));
        _data.cardColor   = _getCardColor  (_cutDNA(dna, 26, 27), _data.borderColor);
        _data.shellColor  = _getShellColor (_cutDNA(dna, 53, 27), _data.borderColor);

        _data.size = _getSize(_data.lusdAmount);
    }

    function _getSolidBorderColor(EggTraitWeights.BorderColor _color)
        private
        pure
        returns (string memory)
    {
        return (
            _color == EggTraitWeights.BorderColor.White  ?    "#fff" :
            _color == EggTraitWeights.BorderColor.Black  ?    "#000" :
            _color == EggTraitWeights.BorderColor.Bronze ? "#cd7f32" :
            _color == EggTraitWeights.BorderColor.Silver ? "#c0c0c0" :
            _color == EggTraitWeights.BorderColor.Gold   ? "#ffd700" : ""
        );
    }

    function _getSolidCardColor(EggTraitWeights.CardColor _color)
        private
        pure
        returns (string memory)
    {
        return (
            _color == EggTraitWeights.CardColor.Red    ? "#ea394e" :
            _color == EggTraitWeights.CardColor.Green  ? "#5caa4b" :
            _color == EggTraitWeights.CardColor.Blue   ? "#008bf7" :
            _color == EggTraitWeights.CardColor.Purple ? "#9d34e8" :
            _color == EggTraitWeights.CardColor.Pink   ? "#e54cae" : ""
        );
    }

    function _getCardGradient(EggTraitWeights.CardColor _color)
        private
        pure
        returns (bool, string[2] memory)
    {
        return (
            _color == EggTraitWeights.CardColor.YellowPink ? (true, ["#ffd200", "#ff0087"]) :
            _color == EggTraitWeights.CardColor.BlueGreen  ? (true, ["#008bf7", "#58b448"]) :
            _color == EggTraitWeights.CardColor.PinkBlue   ? (true, ["#f900bd", "#00a7f6"]) :
            _color == EggTraitWeights.CardColor.RedPurple  ? (true, ["#ea394e", "#9d34e8"]) :
            _color == EggTraitWeights.CardColor.Bronze     ? (true, ["#804a00", "#cd7b26"]) :
            _color == EggTraitWeights.CardColor.Silver     ? (true, ["#71706e", "#b6b6b6"]) :
            _color == EggTraitWeights.CardColor.Gold       ? (true, ["#aa6c39", "#ffae00"]) :
                                                             (false, ["", ""])
        );
    }

    function _calcDerivedData(CommonData memory _data) private pure {
        _data.tokenIDString = _data.tokenID.toString();
        (_data.hasCardGradient, _data.cardGradient) = _getCardGradient(_data.cardColor);

        _data.borderStyle = abi.encodePacked(
            'fill:',
            _data.borderColor == EggTraitWeights.BorderColor.Rainbow
                ? abi.encodePacked('url(#cb-egg-', _data.tokenIDString, '-card-rainbow-gradient)')
                : bytes(_getSolidBorderColor(_data.borderColor))
        );

        _data.cardStyle = abi.encodePacked(
            'fill:',
            _data.cardColor == EggTraitWeights.CardColor.Rainbow
                ? abi.encodePacked('url(#cb-egg-', _data.tokenIDString, '-card-rainbow-gradient)')
                : _data.hasCardGradient
                ? abi.encodePacked('url(#cb-egg-', _data.tokenIDString, '-card-diagonal-gradient)')
                : bytes(_getSolidCardColor(_data.cardColor))
        );
    }

    function _getMetadataCommonDerivedAttributes(CommonData memory _data)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '{"trait_type":"Size","value":"', _getSizeName(_data.size), '"},'
            '{"trait_type":"Border","value":"', _getBorderName(_data.borderColor), '"},',
            '{"trait_type":"Card","value":"', _getCardName(_data.cardColor), '"},'
        );
    }

    function _getMetadataAttributes(CommonData memory _data, bytes memory _extraAttributes)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '"attributes":[',
                '{"display_type":"date","trait_type":"Created","value":', _data.startTime.toString(), '},',
                '{"display_type":"number","trait_type":"Bond Amount","value":', _formatDecimal(_data.lusdAmount), '},',
                '{"trait_type":"Bond Status","value":"', _getBondStatusName(IChickenBondManager.BondStatus(_data.status)), '"},',
                _getMetadataCommonDerivedAttributes(_data),
                _extraAttributes,
            ']'
        );
    }

    function _getBondStatusName(IChickenBondManager.BondStatus _status)
        private
        pure
        returns (string memory)
    {
        return (
            _status == IChickenBondManager.BondStatus.chickenedIn  ? "Chickened In"  :
            _status == IChickenBondManager.BondStatus.chickenedOut ? "Chickened Out" :
            _status == IChickenBondManager.BondStatus.active       ? "Active"        : ""
        );
    }

    function _getBorderName(EggTraitWeights.BorderColor _border)
        private
        pure
        returns (string memory)
    {
        return (
            _border == EggTraitWeights.BorderColor.White    ? "White"   :
            _border == EggTraitWeights.BorderColor.Black    ? "Black"   :
            _border == EggTraitWeights.BorderColor.Bronze   ? "Bronze"  :
            _border == EggTraitWeights.BorderColor.Silver   ? "Silver"  :
            _border == EggTraitWeights.BorderColor.Gold     ? "Gold"    :
            _border == EggTraitWeights.BorderColor.Rainbow  ? "Rainbow" : ""
        );
    }

    function _getCardName(EggTraitWeights.CardColor _card) private pure returns (string memory) {
        return (
            _card == EggTraitWeights.CardColor.Red        ? "Red"         :
            _card == EggTraitWeights.CardColor.Green      ? "Green"       :
            _card == EggTraitWeights.CardColor.Blue       ? "Blue"        :
            _card == EggTraitWeights.CardColor.Purple     ? "Purple"      :
            _card == EggTraitWeights.CardColor.Pink       ? "Pink"        :
            _card == EggTraitWeights.CardColor.YellowPink ? "Yellow-Pink" :
            _card == EggTraitWeights.CardColor.BlueGreen  ? "Blue-Green"  :
            _card == EggTraitWeights.CardColor.PinkBlue   ? "Pink-Blue"   :
            _card == EggTraitWeights.CardColor.RedPurple  ? "Red-Purple"  :
            _card == EggTraitWeights.CardColor.Bronze     ? "Bronze"      :
            _card == EggTraitWeights.CardColor.Silver     ? "Silver"      :
            _card == EggTraitWeights.CardColor.Gold       ? "Gold"        :
            _card == EggTraitWeights.CardColor.Rainbow    ? "Rainbow"     : ""
        );
    }

    function _getSizeName(Size _size) private pure returns (string memory) {
        return (
            _size == Size.Tiny   ? "Tiny"   :
            _size == Size.Small  ? "Small"  :
            _size == Size.Normal ? "Normal" :
            _size == Size.Big    ? "Big"    : ""
        );
    }

    function _getMonthName(uint256 _month) private pure returns (string memory) {
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

    function _formatDate(uint256 timestamp) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                _getMonthName(DateTime.getMonth(timestamp)),
                ' ',
                DateTime.getDay(timestamp).toString(),
                ', ',
                DateTime.getYear(timestamp).toString()
            )
        );
    }

    function _formatDecimal(uint256 decimal) private pure returns (string memory) {
        return ((decimal + 0.5e18) / 1e18).toString();
    }

    function _getSVGDefCardDiagonalGradient(CommonData memory _data)
        private
        pure
        returns (bytes memory)
    {
        if (!_data.hasCardGradient) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _data.tokenIDString, '-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-color="', _data.cardGradient[0], '"/>',
                '<stop offset="1" stop-color="', _data.cardGradient[1], '"/>',
            '</linearGradient>'
        );
    }

    function _getSVGDefCardRainbowGradient(CommonData memory _data)
        private
        pure
        returns (bytes memory)
    {
        if (
            _data.cardColor != EggTraitWeights.CardColor.Rainbow &&
            _data.borderColor != EggTraitWeights.BorderColor.Rainbow
        ) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _data.tokenIDString, '-card-rainbow-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
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

    function _getSVGDefCardRadialGradient(CommonData memory _data)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<radialGradient id="cb-egg-', _data.tokenIDString, '-card-radial-gradient" cx="50%" cy="45%" r="38%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-opacity="0"/>',
                '<stop offset="0.25" stop-opacity="0"/>',
                '<stop offset="1" stop-color="#000" stop-opacity="1"/>',
            '</radialGradient>'
        );
    }

    function _getSVGBorder(CommonData memory _data, bool _darkMode)
        private
        pure
        returns (bytes memory)
    {
        if (_darkMode && _data.borderColor == EggTraitWeights.BorderColor.Black) {
            // We will use the black radial gradient as border (covering the entire card)
            return bytes('');
        }

        return abi.encodePacked(
            '<rect style="', _data.borderStyle, '" width="100%" height="100%" rx="37.5"/>'
        );
    }

    function _getSVGCard(CommonData memory _data) private pure returns (bytes memory) {
        return abi.encodePacked(
            _data.cardColor == EggTraitWeights.CardColor.Rainbow && _data.borderColor == EggTraitWeights.BorderColor.Rainbow
                ? bytes('') // Rainbow gradient already placed by border
                : abi.encodePacked(
                    '<rect style="', _data.cardStyle, '" x="30" y="30" width="690" height="990" rx="37.5"/>'
                ),

            _data.cardColor == EggTraitWeights.CardColor.Rainbow
                ? '<rect fill="#000" opacity="0.05" x="30" y="30" width="690" height="990" rx="37.5"/>'
                : ''
        );
    }

    function _getSVGCardRadialGradient(CommonData memory _data)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<rect style="fill:url(#cb-egg-', _data.tokenIDString, '-card-radial-gradient);mix-blend-mode:hard-light" ',
                _data.borderColor == EggTraitWeights.BorderColor.Black
                    ? 'width="100%" height="100%"'
                    : 'x="30" y="30" width="690" height="990"',
                ' rx="37.5"/>'
        );
    }

    function _getSVGTextTag(string memory _child, string memory _attr)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<text ', _attr, ' fill="#fff" font-family="''Arial Black'', Arial" font-weight="800" text-anchor="middle" x="50%">',
                _child,
            '</text>'
        );
    }

    function _getSVGText(CommonData memory _data, string memory _subtitle)
        private
        pure
        returns (bytes memory)
    {
        string memory tokenID = string(abi.encodePacked('ID: ', _data.tokenIDString));
        string memory lusdAmount = _formatDecimal(_data.lusdAmount);
        string memory startTime = _formatDate(_data.startTime);

        return abi.encodePacked(
            _getSVGTextTag('LUSD',     'y="14%" font-size="72px"'),
            _getSVGTextTag(tokenID,    'y="19%" font-size="30px"'),
            _getSVGTextTag(_subtitle,  'y="72%" font-size="40px"'),
            _getSVGTextTag(lusdAmount, 'y="81%" font-size="64px"'),
            _getSVGTextTag(startTime,  'y="91%" font-size="30px" opacity="0.6"')
        );
    }
}

abstract contract BondNFTArtworkBase is IBondNFTArtwork {
    BondNFTArtworkCommon public immutable common;

    constructor(BondNFTArtworkCommon _common) {
        common = _common;
    }

    ////////////////////////
    // External functions //
    ////////////////////////

    function tokenURI(uint256 _tokenID, IBondNFT.BondExtraData calldata _bondExtraData)
        external
        view
        returns (string memory)
    {
        IChickenBondManager chickenBondManager =
            IChickenBondManagerGetter(msg.sender).chickenBondManager();

        CommonData memory data;
        data.tokenID = _tokenID;
        data.initialHalfDna = _bondExtraData.initialHalfDna;
        data.finalHalfDna = _bondExtraData.finalHalfDna;
        data.troveSize = _bondExtraData.troveSize;
        data.lqtyAmount = _bondExtraData.lqtyAmount;
        data.curveGaugeSlopes = _bondExtraData.curveGaugeSlopes;

        (
            data.lusdAmount,
            data.claimedBLUSD,
            data.startTime,
            data.endTime,
            data.status
        ) = chickenBondManager.getBondData(_tokenID);

        return _tokenURIImplementation(common.calcData(data));
    }

    //////////////////////////////////////////////////////////
    // Abstract functions (to be implemented by subclasses) //
    //////////////////////////////////////////////////////////

    function _tokenURIImplementation(CommonData memory _commonData)
        internal
        view
        virtual
        returns (string memory);

    /////////////////////////////////////////////
    // Internal functions (used by subclasses) //
    /////////////////////////////////////////////

    function _getMetadataJSON(
        CommonData memory _commonData,
        bytes memory _svg,
        bytes memory _extraAttributes
    )
        internal
        view
        returns (string memory)
    {
        return common.getMetadataJSON(_commonData, _svg, _extraAttributes);
    }

    function _getSVGBaseDefs(CommonData memory _commonData, bool _darkMode)
        internal
        view
        returns (bytes memory)
    {
        return common.getSVGBaseDefs(_commonData, _darkMode);
    }

    function _getSVGBase(CommonData memory _commonData, string memory _subtitle, bool _darkMode)
        internal
        view
        returns (bytes memory)
    {
        return common.getSVGBase(_commonData, _subtitle, _darkMode);
    }

    // Shell & chicken share the same color range, but it's no use renaming the enum at this point
    function _getObjectColorName(EggTraitWeights.ShellColor _color)
        internal
        pure
        returns (string memory)
    {
        return (
            _color == EggTraitWeights.ShellColor.OffWhite      ? "Off-White"      :
            _color == EggTraitWeights.ShellColor.LightBlue     ? "Light Blue"     :
            _color == EggTraitWeights.ShellColor.DarkerBlue    ? "Darker Blue"    :
            _color == EggTraitWeights.ShellColor.LighterOrange ? "Lighter Orange" :
            _color == EggTraitWeights.ShellColor.LightOrange   ? "Light Orange"   :
            _color == EggTraitWeights.ShellColor.DarkerOrange  ? "Darker Orange"  :
            _color == EggTraitWeights.ShellColor.LightGreen    ? "Light Green"    :
            _color == EggTraitWeights.ShellColor.DarkerGreen   ? "Darker Green"   :
            _color == EggTraitWeights.ShellColor.Bronze        ? "Bronze"         :
            _color == EggTraitWeights.ShellColor.Silver        ? "Silver"         :
            _color == EggTraitWeights.ShellColor.Gold          ? "Gold"           :
            _color == EggTraitWeights.ShellColor.Rainbow       ? "Rainbow"        :
            _color == EggTraitWeights.ShellColor.Luminous      ? "Luminous"       : ""
        );
    }

    function _getSolidObjectColor(EggTraitWeights.ShellColor _color)
        internal
        pure
        returns (string memory)
    {
        return (
            _color == EggTraitWeights.ShellColor.OffWhite      ? "#fff1cb" :
            _color == EggTraitWeights.ShellColor.LightBlue     ? "#e5eff9" :
            _color == EggTraitWeights.ShellColor.DarkerBlue    ? "#aedfe2" :
            _color == EggTraitWeights.ShellColor.LighterOrange ? "#f6dac9" :
            _color == EggTraitWeights.ShellColor.LightOrange   ? "#f8d1b2" :
            _color == EggTraitWeights.ShellColor.DarkerOrange  ? "#fcba92" :
            _color == EggTraitWeights.ShellColor.LightGreen    ? "#c5e8d6" :
            _color == EggTraitWeights.ShellColor.DarkerGreen   ? "#e5daaa" :
            _color == EggTraitWeights.ShellColor.Bronze        ? "#cd7f32" :
            _color == EggTraitWeights.ShellColor.Silver        ? "#c0c0c0" :
            _color == EggTraitWeights.ShellColor.Gold          ? "#ffd700" : ""
        );
    }

    function _isMetallicCardColor(EggTraitWeights.CardColor _color) internal pure returns (bool) {
        return (
            _color == EggTraitWeights.CardColor.Bronze ||
            _color == EggTraitWeights.CardColor.Silver ||
            _color == EggTraitWeights.CardColor.Gold
        );
    }

    function _translateMetallicCardColorToObjectColor(EggTraitWeights.CardColor _color)
        internal
        pure
        returns (EggTraitWeights.ShellColor)
    {
        return (
            _color == EggTraitWeights.CardColor.Bronze ? EggTraitWeights.ShellColor.Bronze :
            _color == EggTraitWeights.CardColor.Silver ? EggTraitWeights.ShellColor.Silver :
                                                         EggTraitWeights.ShellColor.Gold
        );
    }

    function _isMetallicObjectColor(EggTraitWeights.ShellColor _color)
        internal
        pure
        returns (bool)
    {
        return (
            _color == EggTraitWeights.ShellColor.Bronze ||
            _color == EggTraitWeights.ShellColor.Silver ||
            _color == EggTraitWeights.ShellColor.Gold
        );
    }

    function _isLowContrastObjectColor(EggTraitWeights.ShellColor _color)
        internal
        pure
        returns (bool)
    {
        return (
            _color == EggTraitWeights.ShellColor.Bronze ||
            _color == EggTraitWeights.ShellColor.Silver
        );
    }
}
