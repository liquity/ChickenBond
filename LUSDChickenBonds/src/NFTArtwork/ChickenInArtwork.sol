// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";

contract ChickenInArtwork is BondNFTArtworkBase {
    using Strings for uint8;
    using Strings for uint256;

    struct ChickenInData {
        // Attributes derived from the DNA
        ShellColor chickenColor;
        uint8 comb;
        uint8 beak;
        uint8 tail;
        uint8 wing;

        // Further data derived from the attributes
        bool darkMode;
        bool hasLQTY;
        bool hasTrove;
        bool hasLlama;
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

    function _getChickenColor(uint256 _rand) private pure returns (ShellColor) {
        // TODO
        return ShellColor(_rand * 13 / 1e18);
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

        _chickenInData.darkMode = _chickenInData.chickenColor == ShellColor.Luminous;
        // TODO hasLQTY, hasTrove, hasLlama
    }

    function _getMetadataOptionalAttributes(ChickenInData memory _chickenInData)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            // TODO change name if we go with something else for LQTY
            _chickenInData.hasLQTY ? '{"value":"LQTY Band"}' : '',
            _chickenInData.hasTrove ? '{"value":"Trove Badge"}' : '',
            _chickenInData.hasLlama ? '{"value":"Llama Badge"}' : ''
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

    function _getSVG(CommonData memory _commonData, ChickenInData memory _chickenInData)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                '<defs>',
                    _getSVGBaseDefs(_commonData, _chickenInData.darkMode),
                '</defs>',

                '<g id="co-chicken-', _commonData.tokenID.toString(), '">',
                    _getSVGBase(_commonData, "CHICKEN IN", _chickenInData.darkMode),
                '</g>',
            '</svg>'
        );
    }
}
