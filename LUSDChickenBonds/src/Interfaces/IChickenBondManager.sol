pragma solidity ^0.8.10;


interface IChickenBondManager {
    // constants
    function getIndexOfLusdTokenInCurvePool() external pure returns (int128);

    function createBond(uint256 _lusdAmount) external;
    function chickenOut(uint256 _bondID) external;
    function chickenIn(uint256 _bondID) external;
    function redeem(uint256 _sLUSDToRedeem) external returns (uint256, uint256);

    // getters
    function getIdToBondData(uint256 _bondID) external view returns (uint256, uint256);
}
