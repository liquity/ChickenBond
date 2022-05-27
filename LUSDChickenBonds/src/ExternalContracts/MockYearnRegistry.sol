pragma solidity ^0.8.10;


contract MockYearnRegistry {
    constructor(address _yearnSPVaultAddress, address _yearnCurveVaultAddress, address _lusdTokenAddress, address _curvePoolAddress) {
        vaults[_lusdTokenAddress] = _yearnSPVaultAddress;
        vaults[_curvePoolAddress] = _yearnCurveVaultAddress; 
    }
    
    mapping (address => address) public vaults;

    function latestVault(address _tokenAddress) external view returns (address) {
        return vaults[_tokenAddress];
    }
}
