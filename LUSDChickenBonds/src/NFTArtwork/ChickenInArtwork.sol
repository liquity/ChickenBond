// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";
import "./ChickenInGenerated.sol";
import "./ChickenInTraitWeights.sol";

contract ChickenInArtwork is BondNFTArtworkBase, ChickenInGenerated, ChickenInTraitWeights {
    using Strings for uint8;

    uint256 constant MAX_TROVE_SIZE = 10e24; // 10M

    constructor(
        BondNFTArtworkCommon _common,
        ChickenInGenerated1 _g1,
        ChickenInGenerated2 _g2,
        ChickenInGenerated3 _g3
    )
        BondNFTArtworkBase(_common)
        ChickenInGenerated(_g1, _g2, _g3)
    {}

    ///////////////////////////////////////
    // Abstract function implementations //
    ///////////////////////////////////////

    function _tokenURIImplementation(CommonData memory _commonData)
        internal
        view
        virtual
        override
        returns (string memory)
    {
        ChickenInData memory chickenInData;
        _calcChickenInData(_commonData, chickenInData);

        return _getMetadataJSON(
            _commonData,
            _getSVG(_commonData, chickenInData),
            _getMetadataExtraAttributes(chickenInData)
        );
    }

    ///////////////////////
    // Private functions //
    ///////////////////////

    function _calcChickenInData(
        CommonData memory _commonData,
        ChickenInData memory _chickenInData
    )
        private
        view
    {
        uint80 dna = _commonData.finalHalfDna;
        uint256 troveFactor = uint256(_commonData.troveSize) * 1e18 / MAX_TROVE_SIZE;

        _chickenInData.chickenColor = _getChickenColor(_cutDNA(dna,  0, 16), _commonData.shellColor, troveFactor);
        _chickenInData.comb =         _getChickenComb (_cutDNA(dna, 16, 16), troveFactor);
        _chickenInData.beak =         _getChickenBeak (_cutDNA(dna, 32, 16), troveFactor);
        _chickenInData.tail =         _getChickenTail (_cutDNA(dna, 48, 16), troveFactor);
        _chickenInData.wing =         _getChickenWing (_cutDNA(dna, 64, 16), troveFactor);

        _chickenInData.hasLQTY = _commonData.lqtyAmount > 0;
        _chickenInData.hasTrove = _commonData.troveSize > 0;
        _chickenInData.hasLlama = _commonData.curveGaugeSlopes > 0;

        _chickenInData.darkMode =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous;

        _chickenInData.isRainbow =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Rainbow || (
                _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous &&
                _commonData.cardColor == EggTraitWeights.CardColor.Rainbow
            );

        bool isLuminous = (
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous &&
            _commonData.cardColor != EggTraitWeights.CardColor.Rainbow &&
            !_isMetallicCardColor(_commonData.cardColor)
        );

        _chickenInData.chickenStyle = abi.encodePacked(
            "fill:",
            _chickenInData.isRainbow
                ? string(abi.encodePacked('url(#ci-chicken-', _commonData.tokenIDString, '-chicken-rainbow-gradient)'))
                : _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous && _isMetallicCardColor(_commonData.cardColor)
                ? _getSolidObjectColor(_translateMetallicCardColorToObjectColor(_commonData.cardColor))
                : _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous
                ? "#e5eff9"
                : _getSolidObjectColor(_chickenInData.chickenColor),
            isLuminous
                ? ";mix-blend-mode:luminosity"
                : ""
        );

        _chickenInData.legStyle =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous
                ? _chickenInData.chickenStyle
                : bytes("fill:#21130a");

        _chickenInData.cheekStyle =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Rainbow
                ? bytes("fill:#fcee21")
                : _chickenInData.chickenStyle;

        _chickenInData.bodyShadeStyle = abi.encodePacked(
            "fill:",
            _chickenInData.isRainbow || _isLowContrastObjectColor(_chickenInData.chickenColor)
                ? "#333"
                : "#000",
            ";mix-blend-mode:soft-light"
        );

        _chickenInData.wingShadeStyle = abi.encodePacked(
            "fill:",
            _chickenInData.isRainbow
                ? _chickenInData.wing == 1
                    ? "#000"
                    : "#333"
                : _chickenInData.wing == 1
                    ? "#fff"
                    : "#ccc",
            ";mix-blend-mode:soft-light"
        );

        _chickenInData.wingTipShadeStyle =
            _chickenInData.isRainbow
                ? bytes("fill:#ccc;mix-blend-mode:soft-light")
                : _chickenInData.wingShadeStyle;

        _chickenInData.caruncleStyle =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous || _chickenInData.chickenColor == EggTraitWeights.ShellColor.Rainbow || _isMetallicObjectColor(_chickenInData.chickenColor)
                ? _chickenInData.chickenStyle
                : bytes("fill:#eb5838");

        _chickenInData.beakStyle =
            _chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous || _isMetallicObjectColor(_chickenInData.chickenColor)
                ? _chickenInData.chickenStyle
                : bytes("fill:#f69222");
    }

    function _getMetadataOptionalAttributes(ChickenInData memory _chickenInData)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _chickenInData.hasLQTY ? '{"value":"LQTY Band"},' : '',
            _chickenInData.hasTrove ? '{"value":"Trove Badge"},' : '',
            _chickenInData.hasLlama ? '{"value":"Llama Badge"},' : ''
        );
    }

    function _getMetadataExtraAttributes(ChickenInData memory _chickenInData)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getMetadataOptionalAttributes(_chickenInData),
            '{"trait_type":"Chicken","value":"', _getObjectColorName(_chickenInData.chickenColor), '"},',
            '{"trait_type":"Comb","value":"Comb #', _chickenInData.comb.toString(), '"},',
            '{"trait_type":"Beak","value":"Beak #', _chickenInData.beak.toString(), '"},',
            '{"trait_type":"Tail","value":"Tail #', _chickenInData.tail.toString(), '"},',
            '{"trait_type":"Wing","value":"Wing #', _chickenInData.wing.toString(), '"}'
        );
    }

    function _getSVGStyle(CommonData memory _commonData) private view returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                _getSVGAnimations(_commonData),
            '</style>'
        );
    }

    function _getSVGChickenRainbowGradient(
        CommonData memory _commonData,
        ChickenInData memory _chickenInData
    )
        private
        pure
        returns (bytes memory)
    {
        if (_chickenInData.chickenColor == EggTraitWeights.ShellColor.Luminous) {
            return abi.encodePacked(
                '<linearGradient id="ci-chicken-', _commonData.tokenIDString, '-chicken-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">',
                    '<stop offset="0" stop-color="#3fa9f5"/>',
                    '<stop offset="0.38" stop-color="#39b54a"/>',
                    '<stop offset="0.82" stop-color="#fcee21"/>',
                    '<stop offset="1" stop-color="#fbb03b"/>',
                '</linearGradient>'
            );
        } else {
            return abi.encodePacked(
                '<linearGradient id="ci-chicken-', _commonData.tokenIDString, '-chicken-rainbow-gradient" y1="100%" gradientUnits="objectBoundingBox">',
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
    }

    function _getSVGDefs(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<defs>',
                _getSVGBaseDefs(_commonData, _chickenInData.darkMode),
                _chickenInData.isRainbow
                    ? _getSVGChickenRainbowGradient(_commonData, _chickenInData)
                    : bytes(''),
            '</defs>'
        );
    }

    function _getSVGComb(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGCombPath(_commonData, _chickenInData, _chickenInData.caruncleStyle),
            _isMetallicObjectColor(_chickenInData.chickenColor)
                ? _getSVGCombPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle)
                : bytes(''),
            _isLowContrastObjectColor(_chickenInData.chickenColor)
                ? _getSVGCombPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle)
                : bytes('')
        );
    }

    function _getSVGBeak(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGBeakPath(_commonData, _chickenInData, _chickenInData.beakStyle),
            _isMetallicObjectColor(_chickenInData.chickenColor)
                ? _getSVGBeakPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle)
                : bytes(''),
            _isLowContrastObjectColor(_chickenInData.chickenColor)
                ? _getSVGBeakPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle)
                : bytes('')
        );
    }

    function _getSVGWattle(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGWattlePath(_commonData, _chickenInData.caruncleStyle),
            _isMetallicObjectColor(_chickenInData.chickenColor)
                ? _getSVGWattlePath(_commonData, _chickenInData.bodyShadeStyle)
                : bytes(''),
            _isLowContrastObjectColor(_chickenInData.chickenColor)
                ? _getSVGWattlePath(_commonData, _chickenInData.bodyShadeStyle)
                : bytes('')
        );
    }

    function _getSVGTail(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGTailPath(_commonData, _chickenInData, _chickenInData.chickenStyle),
            _getSVGTailPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle),
            _isLowContrastObjectColor(_chickenInData.chickenColor)
                ? _getSVGTailPath(_commonData, _chickenInData, _chickenInData.bodyShadeStyle)
                : bytes('')
        );
    }

    function _getSVGWing(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<g class="ci-wing">',
                _chickenInData.wing == 1 ? _getSVGWing1(_commonData, _chickenInData) :
                _chickenInData.wing == 2 ? _getSVGWing2(_commonData, _chickenInData) :
                                           _getSVGWing3(_commonData, _chickenInData),
            '</g>'
        );
    }

    function _getSVGTrove(CommonData memory _commonData) private pure returns (bytes memory) {
        return abi.encodePacked(
            '<rect style="', _commonData.borderStyle, '" y="932" width="118" height="118" rx="37.5"/>',
            '<rect style="fill:#a55529" x="36.28" y="963.98" width="54.44" height="19.21" rx="9.61"/>',
            '<rect style="fill:#843b17" x="36.28" y="983.19" width="54.44" height="19.21" rx="9.61"/>',
            '<rect style="fill:gold" x="36.28" y="983.19" width="7.69" height="20.49" rx="3.84"/>',
            '<rect style="fill:gold" x="83.03" y="983.19" width="7.69" height="20.49" rx="3.84"/>',
            '<rect style="fill:#000;mix-blend-mode:soft-light" x="36.28" y="983.19" width="7.69" height="20.49" rx="3.84"/>',
            '<rect style="fill:#000;mix-blend-mode:soft-light" x="83.03" y="983.19" width="7.69" height="20.49" rx="3.84"/>',
            '<path style="fill:gold" d="M90.61,980.24a3.8,3.8,0,0,0,.11-.89V966.54a3.85,3.85,0,0,0-7.69,0v12.81H70.14a4,4,0,0,0-3.93-3.2H60.79a4,4,0,0,0-3.93,3.2H44V966.54a3.85,3.85,0,0,0-7.69,0v12.81a3.8,3.8,0,0,0,.11.89A3.84,3.84,0,0,0,38.84,987h18a4,4,0,0,0,3.93,3.21h5.42A4,4,0,0,0,70.14,987h18a3.84,3.84,0,0,0,2.45-6.79Z"/>',
            '<ellipse style="fill:#000" cx="63.45" cy="981.34" rx="1.94" ry="1.96"/>',
            '<path style="fill:#000" d="M60.87,986.07l1.92-4.68a.72.72,0,0,1,1.33,0L66,986.07a.72.72,0,0,1-.66,1H61.53A.72.72,0,0,1,60.87,986.07Z"/>'
        );
    }

    function _getSVGLlama(CommonData memory _commonData) private pure returns (bytes memory) {
        string memory llamaColor =
            _commonData.borderColor == EggTraitWeights.BorderColor.Bronze
                ? "#a55529"
                : "#cd7f32";

        return abi.encodePacked(
            '<rect style="', _commonData.borderStyle, '" x="632" y="932" width="118" height="118" rx="37.5" />',
            '<path style="fill:', llamaColor, '" d="M710.26,979.9c-.45-2.6-2.28.21-4.93,2.39a5.57,5.57,0,0,0-1.3-.15H678.15V956.22a12.7,12.7,0,0,1-7.28-2.62,2.62,2.62,0,0,0-2.62,2.62v2.08a6.5,6.5,0,0,0-5.82,6.37h-2.81a3,3,0,0,0-3,3v1.89A4.4,4.4,0,0,0,661,974h1.41v37.16a1.86,1.86,0,0,0,1.86,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h2.91v6.29a1.85,1.85,0,0,0,1.85,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h8.74v6.29a1.85,1.85,0,0,0,1.85,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h2.91v6.29a1.86,1.86,0,0,0,1.86,1.86h4.44a1.85,1.85,0,0,0,1.85-1.86V987.7c0-.12,0-.23,0-.34A12.13,12.13,0,0,0,710.26,979.9Z" />',
            '<path style="fill:#fff;mix-blend-mode:soft-light" d="M703.19,982.14h-25a12.52,12.52,0,0,0,25,0Z"/>',
            '<path style="fill:#fff;mix-blend-mode:soft-light" d="M699.22,982.14H682.53a8.35,8.35,0,0,0,16.69,0Z"/>',
            '<path style="fill:#fff;mix-blend-mode:soft-light" d="M695.05,982.14H686.7a4.18,4.18,0,0,0,8.35,0Z"/>',
            '<circle cx="669.7" cy="965.54" r="2.33"/>'
        );
    }

    function _getSVGChickenIn(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            abi.encodePacked(
                _getSVGShadow(_commonData),
                _getSVGLegs(_commonData, _chickenInData),

                '<g class="ci-breath">',
                    _getSVGComb(_commonData, _chickenInData),
                    _getSVGBeak(_commonData, _chickenInData),
                    _getSVGWattle(_commonData, _chickenInData),
                    _getSVGBody(_commonData, _chickenInData),
                    _getSVGEye(_commonData),
                    _getSVGCheek(_commonData, _chickenInData),
                    _getSVGTail(_commonData, _chickenInData),
                '</g>'
            ),
            abi.encodePacked(
                _getSVGWing(_commonData, _chickenInData),

                _chickenInData.hasLQTY ? _getSVGLQTYBand(_commonData) : bytes(''),
                _chickenInData.hasTrove ? _getSVGTrove(_commonData) : bytes(''),
                _chickenInData.hasLlama ? _getSVGLlama(_commonData) : bytes('')
            )
        );
    }

    function _getSVG(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGStyle(_commonData),
                _getSVGDefs(_commonData, _chickenInData),

                '<g id="ci-chicken-', _commonData.tokenIDString, '">',
                    _getSVGBase(_commonData, "CHICKEN IN", _chickenInData.darkMode),
                    _getSVGChickenIn(_commonData, _chickenInData),
                '</g>',
            '</svg>'
        );
    }
}
