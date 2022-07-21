// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Interfaces/IBondNFTArtwork.sol";

contract BondNFT is ERC721Enumerable, Ownable {
    IBondNFTArtwork public artwork;

    address public chickenBondManagerAddress;
    uint256 public tokenSupply; // Total outstanding supply - increases by 1 upon mint, decreases by 1 upon burn.
    uint256 public totalMinted; // Tracks the total ever minted. Used for assigning a unique ID to each new mint.

    constructor(string memory name_, string memory symbol_, address _initialArtworkAddress) ERC721(name_, symbol_) {
        artwork = IBondNFTArtwork(_initialArtworkAddress);
    }

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        require(_chickenBondManagerAddress != address(0), "BondNFT: _chickenBondManagerAddress must be non-zero");
        require(chickenBondManagerAddress == address(0), "BondNFT: setAddresses() can only be called once");

        chickenBondManagerAddress = _chickenBondManagerAddress;
    }

    function setArtworkAddress(address _artworkAddress) external onlyOwner {
        // Make sure addresses have been set, as we'll be renouncing ownership
        require(chickenBondManagerAddress != address(0), "BondNFT: setAddresses() must be called first");

        artwork = IBondNFTArtwork(_artworkAddress);
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

    function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
        require(_exists(_tokenID), "BondNFT: URI query for nonexistent token");

        return address(artwork) != address(0) ? artwork.tokenURI(_tokenID) : "";
    }
}
