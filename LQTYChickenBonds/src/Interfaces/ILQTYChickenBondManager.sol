pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IBLQTYToken.sol";
import "../Interfaces/jar.sol";
import "../Interfaces/IBancorNetwork.sol";


interface ILQTYChickenBondManager {
    function lqtyToken() external view returns (IERC20);
    function bLQTYToken() external view returns (IBLQTYToken);
    function pickleJar() external view returns (IJar);
    function bancorNetwork() external view returns (IBancorNetwork);
    function bntLQTYToken() external view returns (IERC20);

    function createBond(uint256 _lqtyAmount) external returns (uint256);
    function chickenOut(uint256 _bondID) external;
    function chickenIn(uint256 _bondID) external;
    function redeem(uint256 _bLQTYToRedeem) external returns (uint256, uint256);

    // getters
    function calcRedemptionFeePercentage(uint256 _fractionOfBLQTYToRedeem) external view returns (uint256);
    function getBondData(uint256 _bondID) external view returns (uint256, uint256);
    function calcAccruedLQTY(uint256 _bondID) external view returns (uint256);
    function calcAccruedBLQTY(uint256 _bondID) external view returns (uint256);
    function calcBondBLQTYCap(uint256 _bondID) external view returns (uint256);
    function calcTotalPickleJarShareValue() external view returns (uint256);
    function calcTotalBancorPoolShareValue() external view returns (uint256);
    function calcTotalLQTYValue() external view returns (uint256);
    function getPendingLQTY() external view returns (uint256);
    function getAcquiredLQTYInPickleJar() external view returns (uint256);
    function getAcquiredLQTYInBancorPool() external view returns (uint256);
    function getAcquiredLQTY() external view returns (uint256);
    function getPermanentLQTY() external view returns (uint256);
    function getOwnedLQTY() external view returns (uint256);
    function calcSystemBackingRatio() external view returns (uint256);
    function calcUpdatedAccrualParameter() external view returns (uint256);
}
