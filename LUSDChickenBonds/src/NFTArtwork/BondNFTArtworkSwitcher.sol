// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../Interfaces/IBondNFTArtwork.sol";
import "../Interfaces/IChickenBondManager.sol";

interface IChickenBondManagerGetter {
    function chickenBondManager() external view returns (IChickenBondManager);
}

contract BondNFTArtworkSwitcher is IBondNFTArtwork, IChickenBondManagerGetter {
    IChickenBondManager public immutable chickenBondManager;
    IBondNFTArtwork public immutable eggArtwork;
    IBondNFTArtwork public immutable chickenOutArtwork;
    IBondNFTArtwork public immutable chickenInArtwork;

    constructor(
        address _chickenBondManagerAddress,
        address _eggArtworkAddress,
        address _chickenOutArtworkAddress,
        address _chickenInArtworkAddress
    ) {
        chickenBondManager = IChickenBondManager(_chickenBondManagerAddress);
        eggArtwork = IBondNFTArtwork(_eggArtworkAddress);
        chickenOutArtwork = IBondNFTArtwork(_chickenOutArtworkAddress);
        chickenInArtwork = IBondNFTArtwork(_chickenInArtworkAddress);
    }

    function tokenURI(uint256 _tokenID, IBondNFT.BondExtraData calldata _bondExtraData)
        external
        view
        returns (string memory)
    {
        (
            /* uint256 lusdAmount */,
            /* uint64 claimedBLUSD */,
            /* uint64 startTime */,
            /* uint64 endTime */,
            uint8 status
        ) = chickenBondManager.getBondData(_tokenID);

        IBondNFTArtwork artwork = (
            status == uint8(IChickenBondManager.BondStatus.chickenedOut) ? chickenOutArtwork :
            status == uint8(IChickenBondManager.BondStatus.chickenedIn)  ? chickenInArtwork  :
            /* default, including active & nonExistent status */           eggArtwork
        );

        // eggArtwork will handle revert for nonExistent tokens, as per ERC-721
        return artwork.tokenURI(_tokenID, _bondExtraData);
    }
}
