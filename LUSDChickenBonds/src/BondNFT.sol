// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Interfaces/IChickenBondManager.sol";
import "./Interfaces/IBondNFTArtwork.sol";

//import "forge-std/console.sol";

contract BondNFT is ERC721Enumerable, Ownable {
    IChickenBondManager public chickenBondManager;
    IBondNFTArtwork public artwork;

    uint256 immutable public transferLockoutPeriodSeconds;

    constructor(string memory name_, string memory symbol_, address _initialArtworkAddress, uint256 _transferLockoutPeriodSeconds) ERC721(name_, symbol_) {
        artwork = IBondNFTArtwork(_initialArtworkAddress);
        transferLockoutPeriodSeconds = _transferLockoutPeriodSeconds;
    }

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        require(_chickenBondManagerAddress != address(0), "BondNFT: _chickenBondManagerAddress must be non-zero");
        require(address(chickenBondManager) == address(0), "BondNFT: setAddresses() can only be called once");

        chickenBondManager = IChickenBondManager(_chickenBondManagerAddress);
    }

    function setArtworkAddress(address _artworkAddress) external onlyOwner {
        // Make sure addresses have been set, as we'll be renouncing ownership
        require(address(chickenBondManager) != address(0), "BondNFT: setAddresses() must be called first");

        artwork = IBondNFTArtwork(_artworkAddress);
        renounceOwnership();
    }

    function mint(address _bonder) external returns (uint256) {
        requireCallerIsChickenBondsManager();

        // We actually increase totalSupply in `ERC721Enumerable._beforeTokenTransfer` when we `_mint`.
        uint256 tokenID = totalSupply() + 1;
        _mint(_bonder, tokenID);

        return tokenID;
    }

    function requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == address(chickenBondManager), "BondNFT: Caller must be ChickenBondManager");
    }

    function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
        require(_exists(_tokenID), "BondNFT: URI query for nonexistent token");

        return address(artwork) != address(0) ? artwork.tokenURI(_tokenID) : "";
    }

    // Prevent transfers for a period of time after chickening in or out
    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenID) internal virtual override {
        if (_from != address(0)) {
            (,, uint256 endTime,, uint8 status) = chickenBondManager.getBondData(_tokenID);

            require(
                status == uint8(IChickenBondManager.BondStatus.active) ||
                block.timestamp >= endTime + transferLockoutPeriodSeconds,
                "BondNFT: cannot transfer during lockout period"
            );
        }

        super._beforeTokenTransfer(_from, _to, _tokenID);
    }

    function getBondAmount(uint256 _tokenID) external view returns (uint256 amount) {
        (amount,,,,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondStartTime(uint256 _tokenID) external view returns (uint256 startTime) {
        (,startTime,,,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondEndTime(uint256 _tokenID) external view returns (uint256 endTime) {
        (,, endTime,,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondDna(uint256 _tokenID) external view returns (uint256 dna) {
        (,,, dna,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondStatus(uint256 _tokenID) external view returns (uint8 status) {
        (,,,, status) = chickenBondManager.getBondData(_tokenID);
    }
}
