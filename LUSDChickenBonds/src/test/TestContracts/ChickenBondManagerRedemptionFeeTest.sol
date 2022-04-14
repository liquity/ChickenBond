pragma solidity ^0.8.10;

import "./DevTestSetup.sol";


contract ChickenBondManagerDevRedemptionFeeTest is DevTestSetup {

    // _updateRedemptionRateAndTime
    function _checkUpdateRedemptionRate(uint256 _decayedBaseRedemptionRate, uint256 _fractionOfSLUSDToRedeem, uint256 _expectedRate) internal {
        chickenBondManager.updateRedemptionRateAndTime(_decayedBaseRedemptionRate, _fractionOfSLUSDToRedeem);
        //console.log("r:", chickenBondManager.baseRedemptionRate());
        //console.log("e:", _expectedRate);
        assert(chickenBondManager.baseRedemptionRate() == _expectedRate);
    }

    function testUpdateRedemptionRate() public {
        uint256 decayedBaseRedemptionRate = 0;
        uint256 fractionOfSLUSDToRedeem = 0;
        uint256 expectedRate = 0;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);

        decayedBaseRedemptionRate = 1e16;
        fractionOfSLUSDToRedeem = chickenBondManager.BETA() - 1;
        expectedRate = decayedBaseRedemptionRate;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);

        decayedBaseRedemptionRate = 1e16;
        fractionOfSLUSDToRedeem = chickenBondManager.BETA();
        expectedRate = decayedBaseRedemptionRate + 1;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);

        decayedBaseRedemptionRate = 1e16;
        fractionOfSLUSDToRedeem = 2e16;
        expectedRate = 2e16;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);

        decayedBaseRedemptionRate = 1e18;
        fractionOfSLUSDToRedeem = 2e16;
        expectedRate = 1e18;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);

        decayedBaseRedemptionRate = 1e16;
        fractionOfSLUSDToRedeem = 2e18;
        expectedRate = 1e18;
        _checkUpdateRedemptionRate(decayedBaseRedemptionRate, fractionOfSLUSDToRedeem, expectedRate);
    }

    function checkUpdadeRedemptionTime(uint256 _currentTime, uint256 _lastRedemptionTime, uint256 _expectedTime) internal {
        vm.warp(_currentTime);
        chickenBondManager.setLastRedemptionTime(_lastRedemptionTime);

        chickenBondManager.updateRedemptionRateAndTime(0, 0);
        assert(chickenBondManager.lastRedemptionTime() == _expectedTime);
    }

    function testUpdateRedemptionTime() public {
        uint256 currentTime = 1649755222;

        uint256 lastRedemptionTime = currentTime;
        uint256 expectedTime = lastRedemptionTime;
        checkUpdadeRedemptionTime(currentTime, lastRedemptionTime, expectedTime);

        lastRedemptionTime = currentTime - 1;
        expectedTime = lastRedemptionTime;
        checkUpdadeRedemptionTime(currentTime, lastRedemptionTime, expectedTime);

        lastRedemptionTime = currentTime - 59;
        expectedTime = lastRedemptionTime;
        checkUpdadeRedemptionTime(currentTime, lastRedemptionTime, expectedTime);

        lastRedemptionTime = currentTime - 60;
        expectedTime = currentTime;
        checkUpdadeRedemptionTime(currentTime, lastRedemptionTime, expectedTime);

        lastRedemptionTime = currentTime - 6000;
        expectedTime = currentTime;
        checkUpdadeRedemptionTime(currentTime, lastRedemptionTime, expectedTime);

        // TODO
        chickenBondManager.setLastRedemptionTime(currentTime + 1);
        // Expect revert due to underflow
        //vm.expectRevert("Reason: Arithmetic over/underflow");
        //chickenBondManager.updateRedemptionRateAndTime(0, 0);
    }

    // calcRedemptionFeePercentage
    function checkCalcRedemptionFeePercentage(uint256 _lastRedemptionTime, uint256 _baseRedemptionRate, uint256 _expectedRate) internal {
        chickenBondManager.setLastRedemptionTime(_lastRedemptionTime);
        chickenBondManager.setBaseRedemptionRate(_baseRedemptionRate);
        //console.log("r:", chickenBondManager.calcRedemptionFeePercentage());
        //console.log("e:", _expectedRate);
        assert(chickenBondManager.calcRedemptionFeePercentage() == _expectedRate);
    }

    function testCalcRedemptionFeePercentage() public {
        uint256 currentTime = 1649755222;
        vm.warp(currentTime);

        uint256 lastRedemptionTime = currentTime - 6000;
        uint256 baseRedemptionRate = 0;
        uint256 expectedRate = 0;
        checkCalcRedemptionFeePercentage(lastRedemptionTime, baseRedemptionRate, expectedRate);

        lastRedemptionTime = currentTime - 1;
        baseRedemptionRate = 1e16;
        expectedRate = baseRedemptionRate;
        checkCalcRedemptionFeePercentage(lastRedemptionTime, baseRedemptionRate, expectedRate);

        lastRedemptionTime = currentTime - 59;
        baseRedemptionRate = 1e16;
        expectedRate = baseRedemptionRate;
        checkCalcRedemptionFeePercentage(lastRedemptionTime, baseRedemptionRate, expectedRate);

        lastRedemptionTime = currentTime - 60;
        baseRedemptionRate = 1e16;
        expectedRate = 9990377588337830;
        checkCalcRedemptionFeePercentage(lastRedemptionTime, baseRedemptionRate, expectedRate);

        lastRedemptionTime = currentTime - 6000;
        baseRedemptionRate = 1e16;
        expectedRate = 9082183626943678;
        checkCalcRedemptionFeePercentage(lastRedemptionTime, baseRedemptionRate, expectedRate);
    }


    // _minutesPassedSinceLastFeeOp
    function testMinutesPassedSinceLastRedemption() public {
        uint256 currentTime = 1649755222;
        vm.warp(currentTime);

        chickenBondManager.setLastRedemptionTime(currentTime);
        assertTrue(chickenBondManager.minutesPassedSinceLastRedemption() == 0);

        chickenBondManager.setLastRedemptionTime(currentTime - 59);
        assertTrue(chickenBondManager.minutesPassedSinceLastRedemption() == 0);

        chickenBondManager.setLastRedemptionTime(currentTime - 60);
        assertTrue(chickenBondManager.minutesPassedSinceLastRedemption() == 1);

        chickenBondManager.setLastRedemptionTime(currentTime - 600);
        assertTrue(chickenBondManager.minutesPassedSinceLastRedemption() == 10);

        chickenBondManager.setLastRedemptionTime(currentTime - 1234*60 - 30);
        assertTrue(chickenBondManager.minutesPassedSinceLastRedemption() == 1234);

        // TODO
        chickenBondManager.setLastRedemptionTime(currentTime + 1);
        // Expect revert due to underflow
        //vm.expectRevert("Reason: Arithmetic over/underflow");
        //chickenBondManager.minutesPassedSinceLastRedemption();
    }
}
