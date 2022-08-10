// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "../Interfaces/IBondNFTArtwork.sol";
import "../Interfaces/IChickenBondManager.sol";

interface IChickenBondManagerGetter {
    function chickenBondManager() external view returns (IChickenBondManager);
}

contract SimpleEggArtwork is IBondNFTArtwork {
    using Strings for uint256;

    struct BondData {
        uint256 tokenID;
        uint256 lusdAmount;
        uint256 startTime;
        uint256 endTime;
        uint128 initialHalfDna;
        uint128 finalHalfDna;
        uint8 status;
    }

    function tokenURI(uint256 _tokenID) external view returns (string memory) {
        IChickenBondManager chickenBondManager =
            IChickenBondManagerGetter(msg.sender).chickenBondManager();

        BondData memory bondData;
        bondData.tokenID = _tokenID;
        (
            bondData.lusdAmount,
            bondData.startTime,
            bondData.endTime,
            bondData.initialHalfDna,
            bondData.finalHalfDna,
            bondData.status
        ) = chickenBondManager.getBondData(_tokenID);

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(bytes(_getMetadataJSON(bondData)))
            )
        );
    }

    function _getMetadataJSON(BondData memory bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '{',
				'"name":"LUSD Chicken #', bondData.tokenID.toString(), '",',
				'"description":"LUSD Chicken Bonds",',
				'"image":"data:image/svg+xml;base64,', Base64.encode(_getSVG(bondData)), '"',
			'}'
        );
    }

    function _getSVGStyle() internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                '#egg-1 {',
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

    function _getSVGCard(BondData memory bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<rect fill="#fff" mix-blend-mode="color-dodge" width="750" height="1050" rx="37.5"/>',
            '<rect fill="#008bf7" x="30" y="30" width="690" height="990" rx="37.5"/>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="72px" font-weight="800" transform="translate(266.85 151.52)">LUSD</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" transform="translate(338.41 204.52)">ID: ', bondData.tokenID.toString(), '</text>',
            '<ellipse fill="#0a102e" cx="375.25" cy="618.75" rx="100" ry="19"/>'
        );
    }

    function _getSVGEgg(BondData memory bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<g id="egg-', bondData.tokenID.toString(), '">',
                '<path fill="#fff1cb" d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"/>',
                '<path fill="#fce3b1" d="M443.61,326.7c19.9,34.86,31.91,75.58,31.91,109.2,0,75.6-60.67,136.88-135.5,136.88a134.08,134.08,0,0,1-87.53-32.41C274.2,586.72,320.9,618.78,375,618.78c74.83,0,135.5-61.28,135.5-136.88C510.52,431.58,483.64,365.37,443.61,326.7Z"/>',
                '<path fill="#fff8e9" d="M298.26,367.33c-10,22.65-9.13,49.22,5.42,60.19,16.26,12.25,39.81,15,61.63-5.22,20.95-19.43,39.13-73.24,2.07-92.5C347.08,319.25,309.31,342.25,298.26,367.33Z"/>',
            '</g>'
        );
    }

    function _getSVGBondData(BondData memory bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="40px" font-weight="800" transform="translate(205.04 755.68)">BOND AMOUNT</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="64px" font-weight="800" transform="translate(289.63 848.68)">', (bondData.lusdAmount / 1e18).toString(), '</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" transform="translate(252.17 950.49)" opacity="0.6">JANUARY 1, 1970</text>'
        );
    }

    function _getSVG(BondData memory bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGStyle(),
                _getSVGCard(bondData),
                _getSVGEgg(bondData),
                _getSVGBondData(bondData),
            '</svg>'
        );
    }
}
