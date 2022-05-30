pragma solidity ^0.8.10;
import "../../BLUSDToken.sol";

contract BLUSDTokenTester is BLUSDToken {

    constructor(string memory name_, string memory symbol_) BLUSDToken(name_, symbol_) {}

    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here

        _mint(_account, _amount);
    }
}
