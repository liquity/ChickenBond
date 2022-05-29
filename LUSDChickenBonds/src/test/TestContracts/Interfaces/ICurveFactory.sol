pragma solidity ^0.8.10;


interface ICurveFactory {
    function deploy_plain_pool(string memory _name, string memory _symbol, address[4] memory _coins, uint256 _A, uint256 _fee, uint256 _asset_type, uint256 _implementation_idx) external returns (address);
    function deploy_gauge(address _pool) external returns (address);
    function admin() external returns (address);
}
