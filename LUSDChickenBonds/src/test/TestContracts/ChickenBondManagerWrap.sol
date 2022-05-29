// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../ChickenBondManager.sol";


// Wrapper of ChickenBondManager to allow calling internal functions
contract ChickenBondManagerWrap is ChickenBondManager {
    constructor
        (
            ExternalAdresses memory _externalContractAddresses,
            uint256 _targetAverageAgeSeconds,
            uint256 _initialAccrualParameter,
            uint256 _minimumAccrualParameter,
            uint256 _accrualAdjustmentRate,
            uint256 _accrualAdjustmentPeriodSeconds,
            uint256 _CHICKEN_IN_AMM_TAX
        )
        ChickenBondManager(
            _externalContractAddresses,
            _targetAverageAgeSeconds,
            _initialAccrualParameter,
            _minimumAccrualParameter,
            _accrualAdjustmentRate,
            _accrualAdjustmentPeriodSeconds,
            _CHICKEN_IN_AMM_TAX
        )
    {}

    // wrappers
    function updateRedemptionFeePercentage(uint256 _fractionOfBLUSDToRedeem) external returns (uint256) {
        return _updateRedemptionFeePercentage(_fractionOfBLUSDToRedeem);
    }

    function minutesPassedSinceLastRedemption() external view returns (uint256) {
        return _minutesPassedSinceLastRedemption();
    }

    function calcAccruedBLUSD(uint256 _startTime, uint256 _lusdAmount, uint256 _backingRatio, uint256 _accrualParameter) external view returns (uint256) {
        return _calcAccruedBLUSD(_startTime, _lusdAmount, _backingRatio, _accrualParameter);
    }

    // setters

    function setLastRedemptionTime(uint256 _lastRedemptionTime) external {
        lastRedemptionTime = _lastRedemptionTime;
    }

    function setBaseRedemptionRate(uint256 _baseRedemptionRate) external {
        baseRedemptionRate = _baseRedemptionRate;
    }
}
