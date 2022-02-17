// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "../../ExternalContracts/MockLUSDToken.sol";

contract LUSDTokenTester is MockLUSDToken {
    
    constructor( 
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress
    ) 
    public MockLUSDToken(_troveManagerAddress,
                      _stabilityPoolAddress,
                      _borrowerOperationsAddress) {}
    
    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here

        _mint(_account, _amount);
    }
}