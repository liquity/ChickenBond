pragma solidity ^0.8.11;

import "../Interfaces/ILQTYStaking.sol";


contract MockLQTYStaking is ILQTYStaking {
    uint256 private stake;

    function setStake(uint256 _stake) external {
        stake = _stake;
    }

    function stakes(address) external view returns (uint256) {
        return stake;
    }
}
