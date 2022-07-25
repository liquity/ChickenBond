// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IBondNFT is IERC721Enumerable {
    function mint(address _bonder) external returns (uint256);
}
