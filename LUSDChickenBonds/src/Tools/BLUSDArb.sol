// based on https://etherscan.io/address/0xf9a0e641c98f964b1c732661fab9d5b96af28d49#code
pragma solidity ^0.8.14;

import "../Tools/Interfaces/IUniswapReserve.sol";
import "forge-std/console.sol"; // TODO


interface ICurvePool {
    function get_dy(uint i, uint j, uint dx) external view returns(uint);
    function get_dy_underlying(int128 i, int128 j, uint dx) external view returns(uint);
    function exchange(uint i, uint j, uint dx, uint minDy, bool useEth) external payable;
    function exchange_underlying(int128 i, int128 j, uint dx, uint minDy) external returns(uint);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external;
}
interface ICurvePool2 is ICurvePool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;
}
interface ICurvePool3 is ICurvePool {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
}

interface ERC20Like {
    function approve(address spender, uint value) external returns(bool);
    function transfer(address to, uint value) external returns(bool);
    function balanceOf(address a) external view returns(uint);
}


contract BLUSDArb {
    ERC20Like constant BLUSD = ERC20Like(0xB9D7DdDca9a4AC480991865EfEf82E01273F79C3);
    ERC20Like constant USDC = ERC20Like(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20Like constant _3CRV_TOKEN = ERC20Like(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ERC20Like constant LUSD3CRV_TOKEN = ERC20Like(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);

    IUniswapReserve constant USDCBLUSD = IUniswapReserve(0x58D6cBf523D132B2c34288a7819d00e28F92B148);
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint160 constant MIN_SQRT_RATIO = 4295128739;

    ICurvePool3 constant _3CRV_POOL = ICurvePool3(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurvePool2 constant LUSD3CRV_POOL = ICurvePool2(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    ICurvePool constant BLUSD_LUSD3CRV_POOL = ICurvePool(0x74ED5d42203806c8CDCf2F04Ca5F60DC777b901c);

    constructor() {
        // BLUSD -> USDC
        USDC.approve(address(_3CRV_POOL), type(uint256).max);
        _3CRV_TOKEN.approve(address(LUSD3CRV_POOL), type(uint256).max);
        LUSD3CRV_TOKEN.approve(address(BLUSD_LUSD3CRV_POOL), type(uint256).max);
        // BLUSD -> USDC
        BLUSD.approve(address(BLUSD_LUSD3CRV_POOL), type(uint256).max);
        LUSD3CRV_TOKEN.approve(address(LUSD3CRV_POOL), type(uint256).max);
        _3CRV_TOKEN.approve(address(_3CRV_POOL), type(uint256).max);
    }

    function swapBLUSDToUSDC(uint bLUSDQty, address bLUSDDest, uint minBLUSDProfit) external payable returns(uint) {
        USDCBLUSD.swap(address(this), false, int256(bLUSDQty), MAX_SQRT_RATIO - 1, new bytes(0));

        uint retVal = BLUSD.balanceOf(address(this));
        require(retVal >= minBLUSDProfit, "insufficient arb profit");
        BLUSD.transfer(bLUSDDest, retVal);

        return retVal;
     }

    function swapUSDCToBLUSD(uint usdcQty, address usdcDest, uint minUSDCProfit) external payable returns(uint) {
        USDCBLUSD.swap(address(this), true, int256(usdcQty), MIN_SQRT_RATIO + 1, new bytes(0));

        uint retVal = USDC.balanceOf(address(this));
        require(retVal >= minUSDCProfit, "insufficient arb profit");
        BLUSD.transfer(usdcDest, retVal);

        return retVal;
     }

    function _uniswapBLUSDToUSDCBCallback(
        int256 /* amount0Delta */,
        int256 amount1Delta,
        bytes calldata /* data */
    ) internal {
        // swap USDC to BLUSD
        //uint usdcAmount = uint(-1 * amount0Delta);
        uint remainingUSDCBal = USDC.balanceOf(address(this));
        console.log(remainingUSDCBal, "remainingUSDCBal");

        // pay for gelato fees
        //threeCrypto.exchange(1, 0, totalUsdcBal, 1, false);
        //remainingUSDCBal = USDC.balanceOf(address(this));

        // USDC => LUSD-3CRV => bLUSD
        _3CRV_POOL.add_liquidity([0, remainingUSDCBal, 0], 0);
        uint256 _3crvBalance = _3CRV_TOKEN.balanceOf(address(this));
        console.log(_3crvBalance, "_3crvBalance");
        LUSD3CRV_POOL.add_liquidity([0, _3crvBalance], 0);
        uint256 lusd3crvBalance = LUSD3CRV_TOKEN.balanceOf(address(this));
        console.log(lusd3crvBalance, "lusd3crvBalance");
        BLUSD_LUSD3CRV_POOL.exchange(1, 0, lusd3crvBalance, 0, false);
        console.log(BLUSD.balanceOf(address(this)), "BLUSD.balanceOf(address(this))");

        BLUSD.transfer(msg.sender, uint(amount1Delta));
    }


    function _uniswapUSDCToBLUSDCallback(
        int256 amount0Delta,
        int256 /* amount1Delta */,
        bytes calldata /* data */
    ) internal {
        // swap BLUSD to USDC
        //uint bLUSDAmount = uint(-1 * amount1Delta);
        uint256 bLUSDBal = BLUSD.balanceOf(address(this));
        console.log(bLUSDBal, "bLUSDBal");

        // pay for gelato fees
        //threeCrypto.exchange(1, 0, totalUsdcBal, 1, false);
        //remainingUSDCBal = USDC.balanceOf(address(this));

        // bLUSD => LUSD-3CRV => USDC
        BLUSD_LUSD3CRV_POOL.exchange(0, 1, bLUSDBal, 0, false);
        uint256 lusd3crvBalance = LUSD3CRV_TOKEN.balanceOf(address(this));
        console.log(lusd3crvBalance, "lusd3crvBalance");
        LUSD3CRV_POOL.remove_liquidity_one_coin(lusd3crvBalance, 1, 0);
        uint256 _3crvBalance = _3CRV_TOKEN.balanceOf(address(this));
        console.log(_3crvBalance, "_3crvBalance");
        _3CRV_POOL.remove_liquidity_one_coin(_3crvBalance, 1, 0);
        console.log(USDC.balanceOf(address(this)), "USDC.balanceOf(address(this))");

        USDC.transfer(msg.sender, uint(amount0Delta));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (msg.sender == address(USDCBLUSD)) {
            if(amount1Delta > 0) {
                _uniswapBLUSDToUSDCBCallback(amount0Delta, amount1Delta, data);
            } else if (amount0Delta > 0) {
                _uniswapUSDCToBLUSDCallback(amount0Delta, amount1Delta, data);
            } else {
                revert("uniswapV3SwapCallback: nothing to swap");
            }
        } else {
            revert("uniswapV3SwapCallback: invalid sender");
        }
    }

    receive() external payable {}
}
