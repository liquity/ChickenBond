// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ILQTYStaking.sol";
import "./Interfaces/IPickleJar.sol";
import "./Interfaces/ICurveGaugeController.sol";
import "./Interfaces/IBondNFTArtwork.sol";
import "./Interfaces/IBondNFT.sol";

//import "forge-std/console.sol";

contract BondNFT is ERC721Enumerable, Ownable, IBondNFT {
    IChickenBondManager public chickenBondManager;
    IBondNFTArtwork public artwork;
    ITroveManager immutable public troveManager;
    IERC20 immutable public lqtyToken;
    ILQTYStaking immutable public lqtyStaking;
    IPickleJar immutable public pickleLQTYJar;
    IERC20 immutable public pickleLQTYFarm;
    ICurveGaugeController immutable public curveGaugeController;
    address immutable public curveLUSD3CRVGauge;
    address immutable public curveLUSDFRAXGauge;

    uint256 immutable public transferLockoutPeriodSeconds;

    mapping (uint256 => BondExtraData) private idToBondExtraData;

    constructor(
        string memory name_,
        string memory symbol_,
        address _initialArtworkAddress,
        uint256 _transferLockoutPeriodSeconds,
        address _troveManagerAddress,
        address _lqtyToken,
        address _lqtyStaking,
        address _pickleLQTYJar,
        address _pickleLQTYFarm,
        address _curveGaugeController,
        address _curveLUSD3CRVGauge,
        address _curveLUSDFRAXGauge
    )
        ERC721(name_, symbol_)
    {
        require(_troveManagerAddress != address(0), "BondNFT: _troveManagerAddress must be non-zero");
        require(_lqtyToken != address(0), "BondNFT: _lqtyToken must be non-zero");
        require(_lqtyStaking != address(0), "BondNFT: _lqtyStaking must be non-zero");
        require(_pickleLQTYJar != address(0), "BondNFT: _pickleLQTYJar must be non-zero");
        require(_pickleLQTYFarm != address(0), "BondNFT: _pickleLQTYFarm must be non-zero");
        require(_curveGaugeController != address(0), "BondNFT: _curveGaugeController must be non-zero");
        require(_curveLUSD3CRVGauge != address(0), "BondNFT: _curveLUSD3CRVGauge must be non-zero");
        require(_curveLUSDFRAXGauge != address(0), "BondNFT: _curveLUSDFRAXGauge must be non-zero");

        artwork = IBondNFTArtwork(_initialArtworkAddress);
        transferLockoutPeriodSeconds = _transferLockoutPeriodSeconds;
        troveManager = ITroveManager(_troveManagerAddress);
        lqtyToken = IERC20(_lqtyToken);
        lqtyStaking = ILQTYStaking(_lqtyStaking);
        pickleLQTYJar = IPickleJar(_pickleLQTYJar);
        pickleLQTYFarm = IERC20(_pickleLQTYFarm);
        curveGaugeController = ICurveGaugeController(_curveGaugeController);
        curveLUSD3CRVGauge = _curveLUSD3CRVGauge;
        curveLUSDFRAXGauge = _curveLUSDFRAXGauge;
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

    function mint(address _bonder, uint256 _permanentSeed) external returns (uint256, uint128) {
        requireCallerIsChickenBondsManager();

        // We actually increase totalSupply in `ERC721Enumerable._beforeTokenTransfer` when we `_mint`.
        uint256 tokenID = totalSupply() + 1;

        //Record first half of DNA
        BondExtraData memory bondExtraData;
        uint128 initialHalfDna = getHalfDna(tokenID, _permanentSeed);
        bondExtraData.initialHalfDna = initialHalfDna;
        idToBondExtraData[tokenID] = bondExtraData;

        _mint(_bonder, tokenID);

        return (tokenID, initialHalfDna);
    }

    function setFinalExtraData(address _bonder, uint256 _tokenID, uint256 _permanentSeed) external returns (uint128) {
        requireCallerIsChickenBondsManager();

        uint128 newDna = getHalfDna(_tokenID, _permanentSeed);
        idToBondExtraData[_tokenID].finalHalfDna = newDna;

        // Liquity Data
        // Trove
        idToBondExtraData[_tokenID].troveSize = troveManager.getTroveDebt(_bonder);
        // LQTY
        uint256 pickleLQTYAmount;
        if (pickleLQTYJar.totalSupply() > 0) {
            pickleLQTYAmount = (pickleLQTYJar.balanceOf(_bonder) + pickleLQTYFarm.balanceOf(_bonder)) * pickleLQTYJar.getRatio();
        }
        idToBondExtraData[_tokenID].lqtyAmount = lqtyToken.balanceOf(_bonder) + lqtyStaking.stakes(_bonder) + pickleLQTYAmount;
        // Curve Gauge votes
        (uint256 curveLUSD3CRVGaugeSlope,,) = curveGaugeController.vote_user_slopes(_bonder, curveLUSD3CRVGauge);
        (uint256 curveLUSDFRAXGaugeSlope,,) = curveGaugeController.vote_user_slopes(_bonder, curveLUSDFRAXGauge);
        idToBondExtraData[_tokenID].curveGaugeSlopes = curveLUSD3CRVGaugeSlope + curveLUSDFRAXGaugeSlope;

        return newDna;
    }

    function getHalfDna(uint256 _tokenID, uint256 _permanentSeed) internal view returns (uint128) {
        return uint128(
            uint256(
                keccak256(abi.encode(_tokenID, block.timestamp, _permanentSeed))
            ) >> 128
        );
    }

    function requireCallerIsChickenBondsManager() internal view {
        require(msg.sender == address(chickenBondManager), "BondNFT: Caller must be ChickenBondManager");
    }

    function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
        require(_exists(_tokenID), "BondNFT: URI query for nonexistent token");

        return address(artwork) != address(0) ? artwork.tokenURI(_tokenID, idToBondExtraData[_tokenID]) : "";
    }

    // Prevent transfers for a period of time after chickening in or out
    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenID) internal virtual override {
        if (_from != address(0)) {
            (,, uint256 endTime, uint8 status) = chickenBondManager.getBondData(_tokenID);

            require(
                status == uint8(IChickenBondManager.BondStatus.active) ||
                block.timestamp >= endTime + transferLockoutPeriodSeconds,
                "BondNFT: cannot transfer during lockout period"
            );
        }

        super._beforeTokenTransfer(_from, _to, _tokenID);
    }

    function getBondAmount(uint256 _tokenID) external view returns (uint256 amount) {
        (amount,,,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondStartTime(uint256 _tokenID) external view returns (uint256 startTime) {
        (,startTime,,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondEndTime(uint256 _tokenID) external view returns (uint256 endTime) {
        (,, endTime,) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondInitialHalfDna(uint256 _tokenID) external view returns (uint128 initialHalfDna) {
        return idToBondExtraData[_tokenID].initialHalfDna;
    }

    function getBondInitialDna(uint256 _tokenID) external view returns (uint256 initialDna) {
        return uint256(idToBondExtraData[_tokenID].initialHalfDna);
    }

    function getBondFinalHalfDna(uint128 _tokenID) external view returns (uint128 finalHalfDna) {
        return idToBondExtraData[_tokenID].finalHalfDna;
    }

    function getBondFinalDna(uint256 _tokenID) external view returns (uint256 finalDna) {
        BondExtraData memory bondExtraData = idToBondExtraData[_tokenID];
        return (uint256(bondExtraData.initialHalfDna) << 128) + uint256(bondExtraData.finalHalfDna);
    }

    function getBondStatus(uint256 _tokenID) external view returns (uint8 status) {
        (,,, status) = chickenBondManager.getBondData(_tokenID);
    }

    function getBondExtraData(uint256 _tokenID)
        external
        view
        returns (
            uint128 initialHalfDna,
            uint128 finalHalfDna
            // TODO: Liquity Data
        )
    {
        BondExtraData memory bondExtraData = idToBondExtraData[_tokenID];
        return (bondExtraData.initialHalfDna, bondExtraData.finalHalfDna);
    }
}
