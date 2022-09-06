// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./IChickenBondManager.sol";


interface IBondNFT is IERC721Enumerable {
    struct BondExtraData {
        uint128 initialHalfDna;
        uint128 finalHalfDna;
        uint256 troveSize;   // Debt in LUSD
        uint256 lqtyAmount;  // Holding LQTY, staking or deposited into Pickle
    }

    function mint(address _bonder, uint256 _permanentSeed) external returns (uint256, uint128);
    function setFinalExtraData(address _bonder, uint256 _tokenID, uint256 _permanentSeed) external returns (uint128);
    function chickenBondManager() external view returns (IChickenBondManager);
    function getBondAmount(uint256 _tokenID) external view returns (uint256 amount);
    function getBondStartTime(uint256 _tokenID) external view returns (uint256 startTime);
    function getBondEndTime(uint256 _tokenID) external view returns (uint256 endTime);
    function getBondInitialHalfDna(uint256 _tokenID) external view returns (uint128 initialHalfDna);
    function getBondInitialDna(uint256 _tokenID) external view returns (uint256 initialDna);
    function getBondFinalHalfDna(uint128 _tokenID) external view returns (uint128 finalHalfDna);
    function getBondFinalDna(uint256 _tokenID) external view returns (uint256 finalDna);
    function getBondStatus(uint256 _tokenID) external view returns (uint8 status);
    function getBondExtraData(uint256 _tokenID) external view returns (uint128 initialHalfDna, uint128 finalHalfDna);
}
