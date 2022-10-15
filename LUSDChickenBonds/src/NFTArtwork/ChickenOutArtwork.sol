// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";
import "./ChickenOutGenerated.sol";
import "./ChickenOutTraitWeights.sol";

contract ChickenOutArtwork is BondNFTArtworkBase, ChickenOutGenerated, ChickenOutTraitWeights {
    constructor(
        BondNFTArtworkCommon _common,
        ChickenOutGenerated1 _g1
    )
        BondNFTArtworkBase(_common)
        ChickenOutGenerated(_g1)
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
        ChickenOutData memory chickenOutData;
        _calcChickenOutData(_commonData, chickenOutData);

        return _getMetadataJSON(
            _commonData,
            _getSVG(_commonData, chickenOutData),
            _getMetadataExtraAttributes(_commonData, chickenOutData)
        );
    }

    ///////////////////////
    // Private functions //
    ///////////////////////

    function _getObjectRainbowGradientUrl(string memory _tokenIDString)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            'url(#co-chicken-', _tokenIDString, '-object-rainbow-gradient)'
        );
    }

    function _getObjectFill(EggTraitWeights.ShellColor _color, string memory _tokenIDString)
        private
        pure
        returns (bytes memory)
    {
        return (
            _color == EggTraitWeights.ShellColor.Rainbow     ?
                _getObjectRainbowGradientUrl(_tokenIDString) :
            _color == EggTraitWeights.ShellColor.Luminous    ?
                bytes('#e5eff9')                             :
            // default
                bytes(_getSolidObjectColor(_color))
        );
    }

    function _getObjectStyle(EggTraitWeights.ShellColor _color, string memory _tokenIDString)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            'fill:',
            _getObjectFill(_color, _tokenIDString),
            _color == EggTraitWeights.ShellColor.Luminous ? ';mix-blend-mode:luminosity' : ''
        );
    }

    function _calcChickenOutData(
        CommonData memory _commonData,
        ChickenOutData memory _chickenOutData
    )
        private
        view
    {
        uint80 dna = _commonData.finalHalfDna;

        _chickenOutData.chickenColor = _getChickenColor(_cutDNA(dna, 0, 80), _commonData.shellColor);

        _chickenOutData.darkMode = (
            _commonData.shellColor       == EggTraitWeights.ShellColor.Luminous ||
            _chickenOutData.chickenColor == EggTraitWeights.ShellColor.Luminous
        );

        _chickenOutData.shellStyle = _getObjectStyle(
            _commonData.shellColor,
            _commonData.tokenIDString
        );

        _chickenOutData.chickenStyle = _getObjectStyle(
            _chickenOutData.chickenColor,
            _commonData.tokenIDString
        );
    }

    function _getMetadataExtraAttributes(
        CommonData memory _data,
        ChickenOutData memory _chickenOutData
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '{"trait_type":"Shell","value":"', _getObjectColorName(_data.shellColor), '"},'
            '{"trait_type":"Chicken","value":"', _getObjectColorName(_chickenOutData.chickenColor), '"}'
        );
    }

    function _getSVGStyle(CommonData memory _commonData) private view returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                _getSVGAnimations(_commonData),
            '</style>'
        );
    }

    function _getSVGObjectRainbowGradient(
        CommonData memory _commonData,
        ChickenOutData memory _chickenOutData
    )
        private
        pure
        returns (bytes memory)
    {
        if (
            _commonData.shellColor != EggTraitWeights.ShellColor.Rainbow &&
            _chickenOutData.chickenColor != EggTraitWeights.ShellColor.Rainbow
        ) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="co-chicken-', _commonData.tokenIDString, '-object-rainbow-gradient" y1="100%" gradientUnits="objectBoundingBox">',
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

    function _getSVGDefs(CommonData memory _commonData, ChickenOutData memory _chickenOutData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<defs>',
                _getSVGBaseDefs(_commonData, _chickenOutData.darkMode),
                _getSVGObjectRainbowGradient(_commonData, _chickenOutData),
            '</defs>'
        );
    }

    function _getSVGSpeedLines() private pure returns (bytes memory) {
        return abi.encodePacked(
            '<line style="fill:none;mix-blend-mode:soft-light;stroke:#333;stroke-linecap:round;stroke-miterlimit:10;stroke-width:6px" x1="173" y1="460" x2="227" y2="460"/>',
            '<line style="fill:none;mix-blend-mode:soft-light;stroke:#333;stroke-linecap:round;stroke-miterlimit:10;stroke-width:6px" x1="149" y1="500" x2="203" y2="500"/>'
        );
    }

    function _getSVGChickenOut(CommonData memory _commonData, ChickenOutData memory _chickenOutData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _getSVGSpeedLines(),
            _getSVGShadow(_commonData),

            '<g class="co-chicken">',
                _getSVGLeftLeg(_commonData),
                _getSVGRightLeg(_commonData),
                _getSVGBeak(_commonData),
                _getSVGChicken(_commonData, _chickenOutData),
                _getSVGEye(_commonData),
                _getSVGShell(_commonData, _chickenOutData),
            '</g>'
        );
    }

    function _getSVG(CommonData memory _commonData, ChickenOutData memory _chickenOutData)
        private
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGStyle(_commonData),
                _getSVGDefs(_commonData, _chickenOutData),

                '<g id="co-chicken-', _commonData.tokenIDString, '">',
                    _getSVGBase(_commonData, "CHICKEN OUT", _chickenOutData.darkMode),
                    _getSVGChickenOut(_commonData, _chickenOutData),
                '</g>',
            '</svg>'
        );
    }
}
