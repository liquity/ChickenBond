// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ChickenOutGenerated.sol";

contract ChickenOutArtwork is ChickenOutGenerated {
    using Strings for uint256;

    ///////////////////////////////////////
    // Abstract function implementations //
    ///////////////////////////////////////

    function _tokenURIImplementation(CommonData memory _commonData)
        internal
        pure
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

    function _getChickenColor(uint256 _rand) private pure returns (ShellColor) {
        // TODO
        return ShellColor(_rand * 13 / 1e18);
    }

    function _getObjectRainbowGradientUrl(uint256 _tokenID) private pure returns (bytes memory) {
        return abi.encodePacked(
            'url(#co-chicken-',_tokenID.toString(), '-object-rainbow-gradient)'
        );
    }

    function _getObjectFill(ShellColor _color, uint256 _tokenID)
        private
        pure
        returns (bytes memory)
    {
        return (
            _color == ShellColor.Rainbow  ? _getObjectRainbowGradientUrl(_tokenID) :
            _color == ShellColor.Luminous ? bytes('#e5eff9')                       :
                                            bytes(_getSolidObjectColor(_color))
        );
    }

    function _getObjectStyle(ShellColor _color, uint256 _tokenID)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            'fill: ',
            _getObjectFill(_color, _tokenID),
            _color == ShellColor.Luminous ? '; mix-blend-mode: luminosity' : ''
        );
    }

    function _calcChickenOutData(
        CommonData memory _commonData,
        ChickenOutData memory _chickenOutData
    )
        private
        pure
    {
        uint80 dna = _commonData.finalHalfDna;

        _chickenOutData.chickenColor = _getChickenColor(_cutDNA(dna, 0, 80));

        _chickenOutData.darkMode = (
            _commonData.shellColor       == ShellColor.Luminous ||
            _chickenOutData.chickenColor == ShellColor.Luminous
        );

        _chickenOutData.shellStyle = _getObjectStyle(
            _commonData.shellColor,
            _commonData.tokenID
        );

        _chickenOutData.chickenStyle = _getObjectStyle(
            _chickenOutData.chickenColor,
            _commonData.tokenID
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

    function _getSVGObjectRainbowGradient(
        CommonData memory _commonData,
        ChickenOutData memory _chickenOutData
    )
        private
        pure
        returns (bytes memory)
    {
        if (
            _commonData.shellColor != ShellColor.Rainbow &&
            _chickenOutData.chickenColor != ShellColor.Rainbow
        ) {
            return bytes('');
        }

        return abi.encodePacked(
            '<linearGradient id="co-chicken-', _commonData.tokenID.toString(), '-object-rainbow-gradient" y1="100%" gradientUnits="objectBoundingBox">',
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
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<defs>',
                _getSVGBaseDefs(_commonData, _chickenOutData.darkMode),
                _getSVGObjectRainbowGradient(_commonData, _chickenOutData),
            '</defs>'
        );
    }

    function _getSVGStyle(CommonData memory _commonData) private pure returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                _getSVGRunAnimation(_commonData),
                _getSVGLegAnimation(_commonData),
                _getSVGShadowAnimation(_commonData),
                _getSVGKeyframes(_commonData),
            '</style>'
        );
    }

    function _getSVGSpeedLines() private pure returns (bytes memory) {
        return abi.encodePacked(
            '<line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="173" y1="460" x2="227" y2="460"/>',
            '<line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="149" y1="500" x2="203" y2="500"/>'
        );
    }

    function _getSVGChickenOut(CommonData memory _commonData, ChickenOutData memory _chickenOutData)
        private
        pure
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
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGDefs(_commonData, _chickenOutData),
                _getSVGStyle(_commonData),

                '<g id="co-chicken-', _commonData.tokenID.toString(), '">',
                    _getSVGBase(_commonData, "CHICKEN OUT", _chickenOutData.darkMode),
                    _getSVGChickenOut(_commonData, _chickenOutData),
                '</g>',
            '</svg>'
        );
    }
}
