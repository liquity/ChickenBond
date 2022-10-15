// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ChickenInGenerated.sol";

contract ChickenInArtwork is BondNFTArtworkBase, ChickenInGenerated {
    using Strings for uint8;

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
        _calcChickenOutData(_commonData, chickenInData);

        return _getMetadataJSON(
            _commonData,
            _getSVG(_commonData, chickenInData),
            _getMetadataExtraAttributes(chickenInData)
        );
    }

    ///////////////////////
    // Private functions //
    ///////////////////////

    function _getChickenColor(uint256 _rand) private pure returns (EggTraitWeights.ShellColor) {
        // TODO
        return EggTraitWeights.ShellColor(_rand * 13 / 1e18);
    }

    function _getComb(uint256 _rand) private pure returns (uint8) {
        // TODO
        return 1 + uint8(_rand * 9 / 1e18);
    }

    function _getBeak(uint256 _rand) private pure returns (uint8) {
        // TODO
        return 1 + uint8(_rand * 4 / 1e18);
    }

    function _getTail(uint256 _rand) private pure returns (uint8) {
        // TODO
        return 1 + uint8(_rand * 9 / 1e18);
    }

    function _getWing(uint256 _rand) private pure returns (uint8) {
        // TODO
        return 1 + uint8(_rand * 3 / 1e18);
    }

    function _calcChickenOutData(
        CommonData memory _commonData,
        ChickenInData memory _chickenInData
    )
        private
        pure
    {
        uint80 dna = _commonData.finalHalfDna;

        _chickenInData.chickenColor = _getChickenColor(_cutDNA(dna,  0, 16));
        _chickenInData.comb =         _getComb        (_cutDNA(dna, 16, 16));
        _chickenInData.beak =         _getBeak        (_cutDNA(dna, 32, 16));
        _chickenInData.tail =         _getTail        (_cutDNA(dna, 48, 16));
        _chickenInData.wing =         _getWing        (_cutDNA(dna, 64, 16));

        // TODO hasLQTY, hasTrove, hasLlama

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
                ? string(abi.encodePacked('url(#ci-chicken-', _commonData.tokenID, '-chicken-rainbow-gradient)'))
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
                _getSVGWing(_commonData, _chickenInData)
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
