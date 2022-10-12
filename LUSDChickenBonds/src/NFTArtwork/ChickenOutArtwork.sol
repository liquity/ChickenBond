// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";

contract ChickenOutArtwork is BondNFTArtworkBase {
    using Strings for uint256;

    struct ChickenOutData {
        // Attributes derived from the DNA
        ShellColor chickenColor;

        // Further data derived from the attributes
        bool darkMode;
    }

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

    function _getSVG(CommonData memory _commonData, ChickenOutData memory _chickenOutData)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                '<defs>',
                    _getSVGBaseDefs(_commonData, _chickenOutData.darkMode),
                '</defs>',

                '<g id="co-chicken-', _commonData.tokenID.toString(), '">',
                    _getSVGBase(_commonData, "CHICKEN OUT", _chickenOutData.darkMode),
                '</g>',
            '</svg>'
        );
    }
}
