// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/* TODO: 
- Decide whether we need extra functionality e.g. for OpenSea / other markets, e.g. baseTokenURI
- Decide whether we need an on-chain function for listing all bonds owned by the user, or whether events are sufficient
*/
contract BondNFT is ERC721, Ownable {
    using Counters for Counters.Counter;

    address public chickenBondManagerAddress;
    Counters.Counter private _tokenSupply;

    constructor(string memory name_, string memory symbol_) public ERC721(name_, symbol_) {}

    function setAddresses(address _chickenBondManagerAddress) external onlyOwner {
        chickenBondManagerAddress = _chickenBondManagerAddress;
        renounceOwnership();
    }

    function mint(address _bonder) external returns (uint256) {
        requireCallerIsChickenBondsManager();
        _tokenSupply.increment();

        uint256 tokenID = _tokenSupply.current();
        _safeMint(_bonder, tokenID);
       
        return tokenID;
    } 

    function burn(uint256 _tokenID) external {
        requireCallerIsChickenBondsManager();
        _tokenSupply.decrement();

        _burn(_tokenID);
    } 

    function getCurrentTokenSupply() external view returns (uint256) {
        return _tokenSupply.current();
    }

    function requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == chickenBondManagerAddress, "BondNFT: Caller must be ChickenBondManager");
    }
}