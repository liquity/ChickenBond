pragma solidity ^0.8.11;

import "../Interfaces/ICurveGaugeController.sol";


contract MockCurveGaugeController is ICurveGaugeController {
    uint256 private slope;

    function setSlope(uint256 _slope) external {
        slope = _slope;
    }

    function vote_user_slopes(address, address) external view returns (uint256, uint256, uint256) {
        return (slope, 0, 0);
    }

}
