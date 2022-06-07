pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../Interfaces/jar.sol";
import "../TestContracts/MockERC20.sol";


contract MockPickleJar is IJar, ERC20 {
    MockERC20 private immutable lqtyToken;

    constructor(MockERC20 _lqtyToken) ERC20("LQTY Pickle Jar", "pLQTY") {
        lqtyToken = _lqtyToken;
    }

    function token() external view returns (address) {
        return address(lqtyToken);
    }

    function reward() external view returns (address) {}

    function claimInsurance() external {}

    function getRatio() external view returns (uint256) {
        uint256 totalSupplyCached = totalSupply();
        if (totalSupplyCached == 0) { return 1e18; }
        uint256 bal = balance();
        if (bal > 2**128) { // to avoid overflow, it’s just a mock
            return bal / totalSupplyCached * 1e18;
        }
        return bal * 1e18 / totalSupplyCached;
    }

    function depositAll() external {
        deposit(lqtyToken.balanceOf(msg.sender));
    }

    function balance() public view returns (uint256) {
        return lqtyToken.balanceOf(address(this));
    }

    function deposit(uint256 _amount) public {
        uint256 _pool = balance();
        uint256 shares;

        uint256 totalSupplyCached = totalSupply();
        if (totalSupplyCached == 0) {
            shares = _amount;
        } else {
            shares = _amount * totalSupplyCached / _pool;
        }

        _mint(msg.sender, shares);
        lqtyToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public {
        uint256 tokenAmount;
        if (_shares > 2**128) { // to avoid overflow, it’s just a mock
            tokenAmount = balance() / totalSupply() * _shares;
        } else {
            tokenAmount = balance() * _shares / totalSupply();
        }
        _burn(msg.sender, _shares);
        lqtyToken.transfer(msg.sender, tokenAmount);
    }

    function earn() external {}

    function decimals() public pure override(IJar, ERC20) returns (uint8) {
        return 18;
    }

    function harvest(uint256 _amount) external {
        lqtyToken.unprotectedMint(address(this), _amount);
    }
}
