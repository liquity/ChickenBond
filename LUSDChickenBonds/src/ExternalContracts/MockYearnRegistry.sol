pragma solidity ^0.8.10;


contract MockYearnRegistry {
    mapping (address => address) public vaults;

    constructor(address _yearnCurveVaultAddress, address _curvePoolAddress) {
        vaults[_curvePoolAddress] = _yearnCurveVaultAddress;
    }

    function latestVault(address _tokenAddress) external view returns (address) {
        return vaults[_tokenAddress];
    }
}
