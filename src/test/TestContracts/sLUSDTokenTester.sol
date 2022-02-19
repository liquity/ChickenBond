pragma solidity 0.8.10;
import "../../SLUSDToken.sol";

contract sLUSDTokenTester is SLUSDToken {

    constructor(string memory name_, string memory symbol_) public ER20(name_, symbol_) {}

    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here

        _mint(_account, _amount);
    }
}