// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../Interfaces/IBondNFTArtwork.sol";
import "../../Interfaces/IChickenBondManager.sol";

import "../../BondNFT.sol";
import "../../Interfaces/ITroveManager.sol";
import "../../Interfaces/ILQTYStaking.sol";
import "../../Interfaces/IPickleJar.sol";
import "../../Interfaces/ICurveGaugeController.sol";

//import "forge-std/console.sol";


interface IChickenBondManagerGetter {
    function chickenBondManager() external view returns (IChickenBondManager);
}


contract BondNFTArtworkSwitcherTester is /* IBondNFTArtwork, */ IChickenBondManagerGetter {
    IChickenBondManager public immutable chickenBondManager;
    IBondNFTArtwork public immutable eggArtwork;
    IBondNFTArtwork public immutable chickenOutArtwork;
    IBondNFTArtwork public immutable chickenInArtwork;

    // Extra data
    BondNFT public immutable bondNFT;
    ITroveManager immutable public troveManager;
    IERC20 immutable public lqtyToken;
    ILQTYStaking immutable public lqtyStaking;
    IPickleJar immutable public pickleLQTYJar;
    IERC20 immutable public pickleLQTYFarm;
    ICurveGaugeController immutable public curveGaugeController;
    address immutable public curveLUSD3CRVGauge;
    address immutable public curveLUSDFRAXGauge;

    constructor(
        address _bondNFTAddress,
        address _eggArtworkAddress,
        address _chickenOutArtworkAddress,
        address _chickenInArtworkAddress
    ) {
        bondNFT = BondNFT(_bondNFTAddress);
        chickenBondManager = bondNFT.chickenBondManager();
        eggArtwork = IBondNFTArtwork(_eggArtworkAddress);
        chickenOutArtwork = IBondNFTArtwork(_chickenOutArtworkAddress);
        chickenInArtwork = IBondNFTArtwork(_chickenInArtworkAddress);

        // Extra data
        troveManager = bondNFT.troveManager();
        lqtyToken = bondNFT.lqtyToken();
        lqtyStaking = bondNFT.lqtyStaking();
        pickleLQTYJar = bondNFT.pickleLQTYJar();
        pickleLQTYFarm = bondNFT.pickleLQTYFarm();
        curveGaugeController = bondNFT.curveGaugeController();
        curveLUSD3CRVGauge = bondNFT.curveLUSD3CRVGauge();
        curveLUSDFRAXGauge = bondNFT.curveLUSDFRAXGauge();
    }

    function _uint256ToUint32(uint256 _inputAmount) internal pure returns (uint32) {
        return uint32(Math.min(_inputAmount / 1e18, type(uint32).max));
    }

    function getHalfDna(uint256 _tokenID, uint256 _permanentSeed) internal view returns (uint80) {
        return uint80(uint256(keccak256(abi.encode(_tokenID, block.timestamp, _permanentSeed))));
    }

    function getBondExtraData(uint256 _tokenID, uint256 _permanentSeed) internal view returns (IBondNFT.BondExtraData memory bondExtraData) {
        address bonder = bondNFT.ownerOf(_tokenID);

        bondExtraData.initialHalfDna = uint80(bondNFT.getBondInitialDna(_tokenID));
        uint80 newDna = getHalfDna(_tokenID, _permanentSeed);
        bondExtraData.finalHalfDna = newDna;

        // Liquity Data
        // Trove
        bondExtraData.troveSize = _uint256ToUint32(troveManager.getTroveDebt(bonder));
        // LQTY
        uint256 pickleLQTYAmount;
        if (pickleLQTYJar.totalSupply() > 0) {
            pickleLQTYAmount = (pickleLQTYJar.balanceOf(bonder) + pickleLQTYFarm.balanceOf(bonder)) * pickleLQTYJar.getRatio();
        }
        bondExtraData.lqtyAmount = _uint256ToUint32(
            lqtyToken.balanceOf(bonder) + lqtyStaking.stakes(bonder) + pickleLQTYAmount
        );
        // Curve Gauge votes
        (uint256 curveLUSD3CRVGaugeSlope,,) = curveGaugeController.vote_user_slopes(bonder, curveLUSD3CRVGauge);
        (uint256 curveLUSDFRAXGaugeSlope,,) = curveGaugeController.vote_user_slopes(bonder, curveLUSDFRAXGauge);
        bondExtraData.curveGaugeSlopes = _uint256ToUint32((curveLUSD3CRVGaugeSlope + curveLUSDFRAXGaugeSlope) * bondNFT.CURVE_GAUGE_SLOPES_PRECISION());
    }

    function tokenURITester(uint256 _tokenID, uint8 _status)
        external
        view
        returns (string memory)
    {
        IBondNFT.BondExtraData memory bondExtraData = getBondExtraData(_tokenID, uint256(keccak256(abi.encode(block.number))));

        IBondNFTArtwork artwork = (
            _status == uint8(IChickenBondManager.BondStatus.chickenedOut) ? chickenOutArtwork :
            _status == uint8(IChickenBondManager.BondStatus.chickenedIn)  ? chickenInArtwork  :
            /* default, including active & nonExistent status */            eggArtwork
        );

        // eggArtwork will handle revert for nonExistent tokens, as per ERC-721
        return artwork.tokenURI(_tokenID, bondExtraData);
    }
}
