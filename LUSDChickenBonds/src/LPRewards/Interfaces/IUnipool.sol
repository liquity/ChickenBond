// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


interface IUnipool {
    function uniToken() external view returns (address);
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function withdrawAndClaim() external;
    function claimReward() external;
    function pullRewardAmount(uint256 reward) external;
}
