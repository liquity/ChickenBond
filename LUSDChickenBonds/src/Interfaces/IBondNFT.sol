// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

interface IBondNFT is IERC721 {
    function mint(address _bonder) external returns (uint256);

    function burn(uint256 _tokenID) external;

    function totalSupply() external view returns (uint256);

    function totalMinted() external view returns (uint256);
}
