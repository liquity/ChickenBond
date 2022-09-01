pragma solidity ^0.8.10;

interface ICurveGaugeManagerProxy {
    function deploy_gauge(address _pool, address _gauge_manager) external returns (address);
    function add_reward(address _gauge, address _reward_token, address _distributor) external;
    //function set_reward_distributor(address _gauge, address _reward_token, address _distributor) external;
}
