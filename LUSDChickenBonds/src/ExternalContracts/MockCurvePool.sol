// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../console.sol";
import "../Interfaces/ILUSDToken.sol";
import "../Interfaces/ICurvePool.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MockCurvePool is ERC20, Ownable, ICurvePool {
    IERC20 public lusdToken;
   
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function setAddresses(address _lusdTokenAddress) external onlyOwner {
        lusdToken = ILUSDToken(_lusdTokenAddress);
    }

    function add_liquidity(uint256 _lusdAmount) external {
        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);
       
        uint256 lpShares = calcLUSDToLUSD3CRV(_lusdAmount);
        _mint(msg.sender, lpShares);
    }

    function remove_liquidity(uint256 _lpShares) external {
        uint lusdAmount = calcLUSD3CRVToLUSD(_lpShares);
        lusdToken.transfer(msg.sender, lusdAmount);

        _burn(msg.sender, _lpShares);
    }

    /* Simplified LP shares calculators. Shares issued/burned 1:1 with deposited/withdrawn LUSD respectively.
    * In practice, the conversion will be more complicated and will depend on the pool proportions and sizes. */
    function calcLUSDToLUSD3CRV(uint256 _lusdAmount) public pure returns (uint256) {
        return _lusdAmount;
    }

    function calcLUSD3CRVToLUSD(uint256 _LUSD3CRVAmount) public pure returns (uint256) {
        return _LUSD3CRVAmount;
    }
}