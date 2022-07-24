// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/* TODO: 
- Decide whether we need extra functionality for OpenSea / other markets, e.g. baseTokenURI
*/
contract BondNFT is ERC721Enumerable, Ownable {
    address public chickenBondManagerAddress;
    uint256 public tokenSupply; // Total outstanding supply - increases by 1 upon mint, decreases by 1 upon burn.
    uint256 public totalMinted; // Tracks the total ever minted. Used for assigning a unique ID to each new mint.

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        chickenBondManagerAddress = _chickenBondManagerAddress;
        renounceOwnership();
    }

    function mint(address _bonder) external returns (uint256) {
        requireCallerIsChickenBondsManager();
        tokenSupply++;
        totalMinted++;

        uint256 tokenID = totalMinted;
        _mint(_bonder, tokenID);
       
        return tokenID;
    } 

    function burn(uint256 _tokenID) external {
        requireCallerIsChickenBondsManager();
        tokenSupply--;

        _burn(_tokenID);
    } 

    function requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == chickenBondManagerAddress, "BondNFT: Caller must be ChickenBondManager");
    }
}
