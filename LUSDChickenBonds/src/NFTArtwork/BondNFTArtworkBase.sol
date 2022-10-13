// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "datetime/contracts/BokkyPooBahsDateTimeLibrary.sol";
import "./BondNFTArtworkSwitcher.sol";
import "./EggTraitWeights.sol";

abstract contract BondNFTArtworkBase is IBondNFTArtwork, EggTraitWeights {
    using Strings for uint256;

    enum Size {
        Tiny,
        Small,
        Normal,
        Big
    }

    struct CommonData {
        uint256 tokenID;
        uint256 lusdAmount;
        uint256 claimedBLUSD;
        uint256 startTime;
        uint256 endTime;
        uint80 initialHalfDna;
        uint80 finalHalfDna;
        uint8 status;
        // extra data
        uint256 troveSize;

        // Attributes derived from the DNA
        BorderColor borderColor;
        CardColor cardColor;
        ShellColor shellColor;
        Size size;

        // Further data derived from the attributes
        string solidBorderColor;
        string solidCardColor;
        string solidShellColor;
        bool isBlendedShell;
        bool hasCardGradient;
        string[2] cardGradient;
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
        data.troveSize = uint256(_bondExtraData.troveSize);

        (
            data.lusdAmount,
            data.claimedBLUSD,
            data.startTime,
            data.endTime,
            data.status
        ) = chickenBondManager.getBondData(_tokenID);

        _calcAttributes(data);
        _calcDerivedData(data);

        return _tokenURIImplementation(data);
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

    function _cutDNA(uint256 dna, uint8 startBit, uint8 numBits) internal pure returns (uint256) {
        uint256 ceil = 1 << numBits;
        uint256 bits = (dna >> startBit) & (ceil - 1);

        return bits * 1e18 / ceil; // scaled to [0,1) range
    }

    function _getMetadataJSON(
        CommonData memory _commonData,
        bytes memory _svg,
        bytes memory _extraAttributes
    )
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    abi.encodePacked(
                        '{',
                            '"name":"LUSD Chicken #', _commonData.tokenID.toString(), '",',
                            '"description":"LUSD Chicken Bonds",',
                            '"image":"data:image/svg+xml;base64,', Base64.encode(_svg), '",',
                            '"background_color":"0b112f",',
                            _getMetadataAttributes(_commonData, _extraAttributes),
                        '}'
                    )
                )
            )
        );
    }

    function _getSVGBaseDefs(CommonData memory _commonData, bool _darkMode)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGDefCardDiagonalGradient(_commonData),
            _getSVGDefCardRainbowGradient(_commonData),
            _darkMode ? _getSVGDefCardRadialGradient(_commonData) : bytes('')
        );
    }

    function _getSVGBase(CommonData memory _commonData, string memory _subtitle, bool _darkMode)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGBorder(_commonData),
            _getSVGCard(_commonData),
            _darkMode ? _getSVGCardRadialGradient(_commonData) : bytes(''),
            _getSVGText(_commonData, _subtitle)
        );
    }

    // Shell & chicken share the same color range, but it's no use renaming the enum at this point
    function _getObjectColorName(ShellColor _color) internal pure returns (string memory) {
        return (
            _color == ShellColor.OffWhite      ? "Off-White"      :
            _color == ShellColor.LightBlue     ? "Light Blue"     :
            _color == ShellColor.DarkerBlue    ? "Darker Blue"    :
            _color == ShellColor.LighterOrange ? "Lighter Orange" :
            _color == ShellColor.LightOrange   ? "Light Orange"   :
            _color == ShellColor.DarkerOrange  ? "Darker Orange"  :
            _color == ShellColor.LightGreen    ? "Light Green"    :
            _color == ShellColor.DarkerGreen   ? "Darker Green"   :
            _color == ShellColor.Bronze        ? "Bronze"         :
            _color == ShellColor.Silver        ? "Silver"         :
            _color == ShellColor.Gold          ? "Gold"           :
            _color == ShellColor.Rainbow       ? "Rainbow"        :
            _color == ShellColor.Luminous      ? "Luminous"       : ""
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

    function _getSolidBorderColor(BorderColor _color) private pure returns (string memory) {
        return (
            _color == BorderColor.White  ?    "#fff" :
            _color == BorderColor.Black  ?    "#000" :
            _color == BorderColor.Bronze ? "#cd7f32" :
            _color == BorderColor.Silver ? "#c0c0c0" :
            _color == BorderColor.Gold   ? "#ffd700" : ""
        );
    }

    function _getSolidCardColor(CardColor _color) private pure returns (string memory) {
        return (
            _color == CardColor.Red    ? "#ea394e" :
            _color == CardColor.Green  ? "#5caa4b" :
            _color == CardColor.Blue   ? "#008bf7" :
            _color == CardColor.Purple ? "#9d34e8" :
            _color == CardColor.Pink   ? "#e54cae" : ""
        );
    }

    function _getSolidShellColor(ShellColor _shell, CardColor _card)
        private
        pure
        returns (string memory)
    {
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

    function _getCardGradient(CardColor _color) private pure returns (bool, string[2] memory) {
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

    function _calcDerivedData(CommonData memory _data) private pure {
        _data.solidBorderColor = _getSolidBorderColor(_data.borderColor);
        _data.solidCardColor = _getSolidCardColor(_data.cardColor);
        _data.solidShellColor = _getSolidShellColor(_data.shellColor, _data.cardColor);

        _data.isBlendedShell = _data.shellColor == ShellColor.Luminous && !(
            _data.cardColor == CardColor.Bronze ||
            _data.cardColor == CardColor.Silver ||
            _data.cardColor == CardColor.Gold   ||
            _data.cardColor == CardColor.Rainbow
        );

        (_data.hasCardGradient, _data.cardGradient) = _getCardGradient(_data.cardColor);
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

    function _getBorderName(BorderColor _border) private pure returns (string memory) {
        return (
            _border == BorderColor.White    ? "White"   :
            _border == BorderColor.Black    ? "Black"   :
            _border == BorderColor.Bronze   ? "Bronze"  :
            _border == BorderColor.Silver   ? "Silver"  :
            _border == BorderColor.Gold     ? "Gold"    :
            _border == BorderColor.Rainbow  ? "Rainbow" : ""
        );
    }

    function _getCardName(CardColor _card) private pure returns (string memory) {
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
            '<linearGradient id="cb-egg-', _data.tokenID.toString(), '-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
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
            _data.cardColor != CardColor.Rainbow &&
            _data.borderColor != BorderColor.Rainbow
        ) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="cb-egg-', _data.tokenID.toString(), '-card-rainbow-gradient" y1="100%" gradientUnits="userSpaceOnUse">',
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
            '<radialGradient id="cb-egg-', _data.tokenID.toString(), '-card-radial-gradient" cx="50%" cy="45%" r="38%" gradientUnits="userSpaceOnUse">',
                '<stop offset="0" stop-opacity="0"/>',
                '<stop offset="0.25" stop-opacity="0"/>',
                '<stop offset="1" stop-color="#000" stop-opacity="1"/>',
            '</radialGradient>'
        );
    }

    function _getSVGBorder(CommonData memory _data) private pure returns (bytes memory) {
        if (
            _data.shellColor == ShellColor.Luminous &&
            _data.borderColor == BorderColor.Black
        ) {
            // We will use the black radial gradient as border (covering the entire card)
            return bytes('');
        }

        return abi.encodePacked(
            '<rect ',
                _data.borderColor == BorderColor.Rainbow
                    ? abi.encodePacked('style="fill: url(#cb-egg-', _data.tokenID.toString(), '-card-rainbow-gradient)" ')
                    : abi.encodePacked('fill="', _data.solidBorderColor, '" '),
                'width="100%" height="100%" rx="37.5"',
            '/>'
        );
    }

    function _getSVGCard(CommonData memory _data) private pure returns (bytes memory) {
        return abi.encodePacked(
            _data.cardColor == CardColor.Rainbow && _data.borderColor == BorderColor.Rainbow
                ? bytes('') // Rainbow gradient already placed by border
                : abi.encodePacked(
                    '<rect ',
                        _data.cardColor == CardColor.Rainbow
                            ? abi.encodePacked('style="fill: url(#cb-egg-', _data.tokenID.toString(), '-card-rainbow-gradient)" ')
                            : _data.hasCardGradient
                            ? abi.encodePacked('style="fill: url(#cb-egg-', _data.tokenID.toString(), '-card-diagonal-gradient)" ')
                            : abi.encodePacked('fill="', _data.solidCardColor, '" '),
                        'x="30" y="30" width="690" height="990" rx="37.5"',
                    '/>'
                ),

            _data.cardColor == CardColor.Rainbow
                ? '<rect fill="#000" opacity="0.05" x="30" y="30" width="690" height="990" rx="37.5"/>'
                : ''
        );
    }

    function _getSVGCardRadialGradient(CommonData memory _data) private pure returns (bytes memory) {
        if (_data.shellColor != ShellColor.Luminous) {
            return bytes('');
        }

        return abi.encodePacked(
            '<rect ',
                'style="fill: url(#cb-egg-', _data.tokenID.toString(), '-card-radial-gradient); mix-blend-mode: hard-light" ',
                _data.borderColor == BorderColor.Black
                    ? 'width="100%" height="100%" '
                    : 'x="30" y="30" width="690" height="990" ',
                'rx="37.5"',
            '/>'
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
        string memory tokenID = string(abi.encodePacked('ID: ', _data.tokenID.toString()));
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
