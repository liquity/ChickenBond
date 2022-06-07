// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../LQTYChickenBondManager.sol";


// Wrapper of ChickenBondManager to allow calling internal functions
contract LQTYChickenBondManagerWrap is LQTYChickenBondManager {
    constructor
        (
            ExternalAdresses memory _externalContractAddresses,
            uint256 _targetAverageAgeSeconds,
            uint256 _initialAccrualParameter,
            uint256 _minimumAccrualParameter,
            uint256 _accrualAdjustmentRate,
            uint256 _accrualAdjustmentPeriodSeconds,
            uint256 _CHICKEN_IN_AMM_FEE
        )
        LQTYChickenBondManager(
            _externalContractAddresses,
            _targetAverageAgeSeconds,
            _initialAccrualParameter,
            _minimumAccrualParameter,
            _accrualAdjustmentRate,
            _accrualAdjustmentPeriodSeconds,
            _CHICKEN_IN_AMM_FEE
        )
    {}

    // wrappers
    function updateRedemptionFeePercentage(uint256 _fractionOfBLQTYToRedeem) external returns (uint256) {
        return _updateRedemptionFeePercentage(_fractionOfBLQTYToRedeem);
    }

    function minutesPassedSinceLastRedemption() external view returns (uint256) {
        return _minutesPassedSinceLastRedemption();
    }

    function calcAccruedBLQTY(uint256 _startTime, uint256 _lqtyAmount, uint256 _backingRatio, uint256 _accrualParameter) external view returns (uint256) {
        uint256 bondBLQTYCap = _calcBondBLQTYCap(_lqtyAmount, _backingRatio);
        return _calcAccruedAmount(_startTime, bondBLQTYCap, _accrualParameter);
    }

    // setters

    function setLastRedemptionTime(uint256 _lastRedemptionTime) external {
        lastRedemptionTime = _lastRedemptionTime;
    }

    function setBaseRedemptionRate(uint256 _baseRedemptionRate) external {
        baseRedemptionRate = _baseRedemptionRate;
    }
}
