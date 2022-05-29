pragma solidity ^0.8.10;

import "./ILUSDToken.sol";
import "./IBLUSDToken.sol";
import "./ICurvePool.sol";
import "./IYearnVault.sol";


interface IChickenBondManager {
    function lusdToken() external view returns (ILUSDToken);
    function bLUSDToken() external view returns (IBLUSDToken);
    function curvePool() external view returns (ICurvePool);
    function yearnSPVault() external view returns (IYearnVault);
    function yearnCurveVault() external view returns (IYearnVault);
    // constants
    function INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL() external pure returns (int128);

    function createBond(uint256 _lusdAmount) external;
    function chickenOut(uint256 _bondID) external;
    function chickenIn(uint256 _bondID) external;
    function redeem(uint256 _bLUSDToRedeem) external returns (uint256, uint256, uint256);

    // getters
    function getIdToBondData(uint256 _bondID) external view returns (uint256, uint256);
}
