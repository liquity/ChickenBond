// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IBondNFTArtwork {
    function tokenURI(uint256 _tokenID) external view returns (string memory);
}
