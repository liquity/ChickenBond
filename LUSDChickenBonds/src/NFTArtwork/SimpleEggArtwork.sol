// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "datetime/contracts/BokkyPooBahsDateTimeLibrary.sol";
import "../Interfaces/IBondNFTArtwork.sol";
import "../Interfaces/IChickenBondManager.sol";

contract SimpleEggArtwork is IBondNFTArtwork {
    using Strings for uint256;

    struct BondData {
        uint256 tokenID;
        uint256 lusdAmount;
        uint256 claimedBLUSD;
        uint256 startTime;
        uint256 endTime;
        uint80 initialHalfDna;
        uint80 finalHalfDna;
        uint8 status;
    }

    function tokenURI(uint256 _tokenID, IBondNFT.BondExtraData calldata _bondExtraData) external view returns (string memory) {
        IChickenBondManager chickenBondManager =
            IBondNFT(msg.sender).chickenBondManager();

        BondData memory bondData;
        bondData.tokenID = _tokenID;
        (
            bondData.lusdAmount,
            bondData.claimedBLUSD,
            bondData.startTime,
            bondData.endTime,
            bondData.status
        ) = chickenBondManager.getBondData(_tokenID);
        bondData.initialHalfDna = _bondExtraData.initialHalfDna;
        bondData.finalHalfDna = _bondExtraData.finalHalfDna;

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(bytes(_getMetadataJSON(bondData)))
            )
        );
    }

    function _getMetadataJSON(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '{',
                '"name":"LUSD Chicken #', _bondData.tokenID.toString(), '",',
                '"description":"LUSD Chicken Bonds",',
                '"image":"data:image/svg+xml;base64,', Base64.encode(_getSVG(_bondData)), '",',
                '"background_color":"0b112f"',
            '}'
        );
    }

    function _getMonthString(uint256 _month) internal pure returns (string memory) {
        if (_month ==  1) return "JANUARY";
        if (_month ==  2) return "FEBRUARY";
        if (_month ==  3) return "MARCH";
        if (_month ==  4) return "APRIL";
        if (_month ==  5) return "MAY";
        if (_month ==  6) return "JUNE";
        if (_month ==  7) return "JULY";
        if (_month ==  8) return "AUGUST";
        if (_month ==  9) return "SEPTEMBER";
        if (_month == 10) return "OCTOBER";
        if (_month == 11) return "NOVEMBER";
        if (_month == 12) return "DECEMBER";

        revert("SimpleEggArtwork: _month must be within [1, 12]");
    }

    function _getSVGStyle(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<style>',
                '#egg-', _bondData.tokenID.toString(),' {',
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

    function _getSVGCard(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<rect fill="#fff" mix-blend-mode="color-dodge" width="750" height="1050" rx="37.5"/>',
            '<rect fill="#008bf7" x="30" y="30" width="690" height="990" rx="37.5"/>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="72px" font-weight="800" text-anchor="middle" x="50%" y="151">LUSD</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="204">ID: ',
                _bondData.tokenID.toString(),
            '</text>',
            '<ellipse fill="#0a102e" cx="375.25" cy="618.75" rx="100" ry="19"/>'
        );
    }

    function _getSVGEgg(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<g id="egg-', _bondData.tokenID.toString(), '">',
                '<path fill="#fff1cb" d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"/>',
                '<path fill="#fce3b1" d="M443.61,326.7c19.9,34.86,31.91,75.58,31.91,109.2,0,75.6-60.67,136.88-135.5,136.88a134.08,134.08,0,0,1-87.53-32.41C274.2,586.72,320.9,618.78,375,618.78c74.83,0,135.5-61.28,135.5-136.88C510.52,431.58,483.64,365.37,443.61,326.7Z"/>',
                '<path fill="#fff8e9" d="M298.26,367.33c-10,22.65-9.13,49.22,5.42,60.19,16.26,12.25,39.81,15,61.63-5.22,20.95-19.43,39.13-73.24,2.07-92.5C347.08,319.25,309.31,342.25,298.26,367.33Z"/>',
            '</g>'
        );
    }

    function _getSVGBondData(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="40px" font-weight="800" text-anchor="middle" x="50%" y="755">BOND AMOUNT</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="64px" font-weight="800" text-anchor="middle" x="50%" y="848">',
                ((_bondData.lusdAmount + 0.5e18) / 1e18).toString(),
            '</text>',
            '<text fill="#fff" font-family="''Arial Black'', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="950" opacity="0.6">',
                _getMonthString(DateTime.getMonth(_bondData.startTime)),
                ' ',
                DateTime.getDay(_bondData.startTime).toString(),
                ', ',
                DateTime.getYear(_bondData.startTime).toString(),
            '</text>'
        );
    }

    function _getSVG(BondData memory _bondData) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">',
                _getSVGStyle(_bondData),
                _getSVGCard(_bondData),
                _getSVGEgg(_bondData),
                _getSVGBondData(_bondData),
            '</svg>'
        );
    }
}
