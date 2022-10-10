// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../Interfaces/IChickenBondManager.sol";
import "../../Interfaces/ICurveCryptoPool.sol";
import "./ERC20Faucet.sol";

contract Underling {
    IChickenBondManager public immutable chickenBondManager;
    ERC20Faucet public immutable lusdToken;
    IERC20 public immutable bLUSDToken;
    ICurveCryptoPool public immutable bLUSDCurvePool;

    address public overlord;

    constructor(
        address _chickenBondManagerAddress,
        address _lusdTokenAddress,
        address _bLUSDTokenAddress,
        address _bLUSDCurvePoolAddress
    ) {
        chickenBondManager = IChickenBondManager(_chickenBondManagerAddress);
        lusdToken = ERC20Faucet(_lusdTokenAddress);
        bLUSDToken = IERC20(_bLUSDTokenAddress);
        bLUSDCurvePool = ICurveCryptoPool(_bLUSDCurvePoolAddress);

        // Prevent implementation from being taken over
        overlord = address(0x1337);
    }

    function imprint(address _overlord) external {
        require(overlord == address(0));
        overlord = _overlord;
    }

    modifier onlyOverlord() {
        require(msg.sender == overlord, "Underling: only obeys Overlord");
        _;
    }

    function tap() external onlyOverlord {
        lusdToken.tap();
    }

    function createBond(uint256 _amount) external onlyOverlord {
        lusdToken.approve(address(chickenBondManager), _amount);
        chickenBondManager.createBond(_amount);
    }

    function chickenIn(uint256 _bondID) external onlyOverlord {
        chickenBondManager.chickenIn(_bondID);
    }

    function chickenOut(uint256 _bondID) external onlyOverlord {
        chickenBondManager.chickenOut(_bondID, 0);
    }

    function exchange(uint256 _i, uint256 _j, uint256 _dx, uint256 _minDy) external onlyOverlord {
        IERC20 inputToken = _i == 0 ? bLUSDToken : lusdToken;
        inputToken.approve(address(bLUSDCurvePool), _dx);
        bLUSDCurvePool.exchange(_i, _j, _dx, _minDy);
    }

    function addLiquidity(uint256 _bLUSDAmount, uint256 _lusdAmount) external onlyOverlord {
        bLUSDToken.approve(address(bLUSDCurvePool), _bLUSDAmount);
        lusdToken.approve(address(bLUSDCurvePool), _lusdAmount);
        bLUSDCurvePool.add_liquidity([_bLUSDAmount, _lusdAmount], 0);
    }
}
