// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BondNFTArtworkBase.sol";
import "./ChickenInTraitWeights.sol";


contract ChickenInArtwork is BondNFTArtworkBase, ChickenInTraitWeights {
    uint256 constant MAX_TROVE_SIZE = 10e24; // 10M

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

        uint80 initialDna = _commonData.initialHalfDna;
        BorderColor borderColor = _getBorderColor(_cutDNA(initialDna,  0, 26));
        ShellColor shellColor  = _getShellColor (_cutDNA(initialDna, 53, 27), borderColor);
        uint256 troveFactor = _commonData.troveSize * 1e18 / MAX_TROVE_SIZE;

        _chickenInData.chickenColor = _getChickenColor(_cutDNA(dna,  0, 16), shellColor, troveFactor);
        _chickenInData.comb =         _getChickenComb (_cutDNA(dna, 16, 16), troveFactor);
        _chickenInData.beak =         _getChickenBeak (_cutDNA(dna, 32, 16), troveFactor);
        _chickenInData.tail =         _getChickenTail (_cutDNA(dna, 48, 16), troveFactor);
        _chickenInData.wing =         _getChickenWing (_cutDNA(dna, 64, 16), troveFactor);

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
