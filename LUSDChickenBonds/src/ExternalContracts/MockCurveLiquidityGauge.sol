pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract MockCurveLiquidityGauge {
    function deposit_reward_token(address _reward_token, uint256 _amount) external {
        IERC20(_reward_token).transferFrom(msg.sender, address(this), _amount);
    }
}
