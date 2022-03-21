contract MockYearnRegistry {
    constructor(address _yearnLUSDVaultAddress, address _yearnCurveVaultAddress, address _lusdTokenAddress, address _curvePoolAddress) {
        vaults[_lusdTokenAddress] = _yearnLUSDVaultAddress;
        vaults[_curvePoolAddress] = _yearnCurveVaultAddress; 
    }
    
    mapping (address => address) public vaults;

    function latestVault(address _tokenAddress) external returns (address) {
        return vaults[_tokenAddress];
    }
}