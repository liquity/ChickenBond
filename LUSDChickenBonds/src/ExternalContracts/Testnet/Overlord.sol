// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../../ChickenBondManager.sol";
import "../../BondNFT.sol";
import "../../Interfaces/ICurveCryptoPool.sol";
import "./ERC20Faucet.sol";
import "./Underling.sol";

contract Overlord {
    struct OverlordParams {
        address prototype;
        address lusdTokenAddress;
        address bLUSDTokenAddress;
        address chickenBondManagerAddress;
        address bondNFTAddress;
        address bLUSDCurvePoolAddress;
    }

    address public immutable prototype;
    ERC20Faucet public immutable lusdToken;
    IERC20 public immutable bLUSDToken;
    ChickenBondManager public immutable chickenBondManager;
    BondNFT public immutable bondNFT;
    ICurveCryptoPool public immutable bLUSDCurvePool;

    uint256 public numUnderlings;

    constructor(OverlordParams memory params) {
        prototype = params.prototype;
        lusdToken = ERC20Faucet(params.lusdTokenAddress);
        bLUSDToken = IERC20(params.bLUSDTokenAddress);
        chickenBondManager = ChickenBondManager(params.chickenBondManagerAddress);
        bondNFT = BondNFT(params.bondNFTAddress);
        bLUSDCurvePool = ICurveCryptoPool(params.bLUSDCurvePoolAddress);
    }

    function spawn(uint256 _n) external {
        uint256 numUnderlingsCached = numUnderlings;
        numUnderlings = numUnderlingsCached + _n;

        for (uint256 i = numUnderlingsCached; i < numUnderlingsCached + _n; ++i) {
            Underling underling = Underling(Clones.cloneDeterministic(prototype, bytes32(i)));
            underling.imprint(address(this));
            underling.tap();
        }
    }

    function getUnderling(uint256 _i) public view returns (Underling) {
        require(_i < numUnderlings, "Overlord: index out of bounds");
        return Underling(Clones.predictDeterministicAddress(prototype, bytes32(_i)));
    }

    function _getMarketPrice() internal view returns (uint256) {
        try bLUSDCurvePool.get_dy(0, 1, 1e18) returns (uint256 dy) {
            return dy;
        } catch {
            return 1e36 / bLUSDCurvePool.price_oracle();
        }
    }

    function _absDiff(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a - _b : _b - _a;
    }

    function whip(uint256[] calldata _indices, uint256 _sqrtEffLambda) external {
        uint256 marketPrice = _getMarketPrice();
        uint256 redemptionPrice = chickenBondManager.calcSystemBackingRatio();
        uint256 lambda = marketPrice * 1e18 / redemptionPrice;
        uint256 effLambda = lambda * (1e18 - chickenBondManager.CHICKEN_IN_AMM_FEE());

        require(
            _absDiff(_sqrtEffLambda * _sqrtEffLambda, effLambda) < 0.0001e36,
            "Overlord: _sqrtEffLambda out of date"
        );

        uint256 alpha = chickenBondManager.calcUpdatedAccrualParameter();
        uint256 tOpt = _sqrtEffLambda > 1e18 ? alpha / (_sqrtEffLambda - 1e18) : type(uint256).max;

        for (uint256 j = 0; j < _indices.length; ++j) {
            _whipOne(_indices[j], tOpt, marketPrice);
        }
    }

    function _whipOne(uint256 _i, uint256 _tOpt, uint256 _startingPrice) internal {
        Underling underling = getUnderling(_i);
        uint256 numBonds = bondNFT.balanceOf(address(underling));

        if (numBonds == 0) {
            _createBond(underling);
        } else {
            uint256 lastBondID = bondNFT.tokenOfOwnerByIndex(address(underling), numBonds - 1);
            (
                /* lusdAmount */,
                /* claimedBLUSD */,
                uint64 startTime,
                /* endTime */,
                uint8 lastBondStatus
            ) = chickenBondManager.getBondData(lastBondID);

            if (lastBondStatus == uint8(IChickenBondManager.BondStatus.active)) {
                uint256 bondAge = block.timestamp - startTime; // hehe

                if (
                    bondAge >= _tOpt && (
                        bLUSDToken.totalSupply() > 0 ||
                        bondAge >= chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN()
                    )
                ) {
                    underling.chickenIn(lastBondID);

                    uint256 m = _i % 20;
                    if (m < 1) { // 1 in 20 (5%)
                        // Do nothing (hold)
                    } else if (m < 5) { // 4 in 20 (20%)
                        _addLiquidity(underling);
                    } else {
                        // Only tolerate 1% slippage
                        _sellBLUSD(underling, _startingPrice * 99 / 100);
                    }

                    _createBond(underling);
                }
            } else {
                // In theory, we shouldn't get here, as we create a new bond after chickening in
                _createBond(underling);
            }
        }
    }

    function _createBond(Underling _underling) internal {
        uint256 lusdBalance = lusdToken.balanceOf(address(_underling));
        uint256 minLUSDAmount = chickenBondManager.MIN_BOND_AMOUNT();
        uint256 maxLUSDAmount = Math.max(lusdBalance / 2, minLUSDAmount);

        if (lusdBalance < minLUSDAmount) {
            return;
        }

        uint256 rand = uint256(keccak256(abi.encodePacked(
            block.difficulty,
            block.timestamp,
            _underling
        )));


        uint256 lusdAmount =
            minLUSDAmount +
            (maxLUSDAmount - minLUSDAmount) * uint128(rand) / type(uint128).max;

        _underling.createBond(lusdAmount);
    }

    function _addLiquidity(Underling _underling) internal {
        uint256 bLUSDBalance = bLUSDToken.balanceOf(address(_underling));
        uint256 lusdBalance = lusdToken.balanceOf(address(_underling));
        uint256 priceScale = bLUSDCurvePool.price_scale();
        uint256 balancedLUSD = bLUSDBalance * 1e18 / priceScale;

        if (balancedLUSD <= lusdBalance) {
            try _underling.addLiquidity(bLUSDBalance, balancedLUSD) {} catch {}
        } else {
            // balancedLUSD > lusdBalance
            // => bLUSDBalance * 1e18 / priceScale > lusdBalance
            // => bLUSDBalance > lusdBalance * priceScale / 1e18
            try _underling.addLiquidity(lusdBalance * priceScale / 1e18, lusdBalance) {} catch {}
        }
    }

    function _sellBLUSD(Underling _underling, uint256 _minExchangeRate) internal {
        uint256 dx = bLUSDToken.balanceOf(address(_underling));

        try _underling.exchange(0, 1, dx, dx * _minExchangeRate / 1e18) {} catch {}
    }
}
