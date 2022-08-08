pragma solidity ^0.8.10;


interface ICurveLiquidityGaugeV4 {
    function add_reward(address _reward_token, address _distributor) external;
    function deposit_reward_token(address _reward_token, uint256 _amount) external;

    function reward_data(address _reward_token) external returns (
        address token,
        address distributor,
        uint256 period_finish,
        uint256 rate,
        uint256 last_update,
        uint256 integral
    );
}
