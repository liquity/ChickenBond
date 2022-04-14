// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../ChickenBondManager.sol";


// Wrapper of ChickenBondManager to allow calling internal functions
contract ChickenBondManagerWrap is ChickenBondManager {
    constructor
        (
            address _bondNFTAddress,
            address _lusdTokenAddress,
            address _curvePoolAddress,
            address _yearnLUSDVaultAddress,
            address _yearnCurveVaultAddress,
            address _sLUSDTokenAddress,
            address _yearnRegistryAddress
        )
        ChickenBondManager(
            _bondNFTAddress,
            _lusdTokenAddress,
            _curvePoolAddress,
            _yearnLUSDVaultAddress,
            _yearnCurveVaultAddress,
            _sLUSDTokenAddress,
            _yearnRegistryAddress
        )
    {}

    // wrappers

    function updateRedemptionRateAndTime(uint256 _decayedBaseRedemptionRate, uint256 _fractionOfSLUSDToRedeem) external {
        return _updateRedemptionRateAndTime(_decayedBaseRedemptionRate, _fractionOfSLUSDToRedeem);
    }

    function minutesPassedSinceLastRedemption() external view returns (uint256) {
        return _minutesPassedSinceLastRedemption();
    }

    // setters

    function setLastRedemptionTime(uint256 _lastRedemptionTime) external {
        lastRedemptionTime = _lastRedemptionTime;
    }

    function setBaseRedemptionRate(uint256 _baseRedemptionRate) external {
        baseRedemptionRate = _baseRedemptionRate;
    }
}
