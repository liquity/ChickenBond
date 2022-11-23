pragma solidity ^0.8.14;

import "./TestContracts/Accounts.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "../Tools/Interfaces/IUniswapQuoter.sol";
import "../Tools/BLUSDArb.sol";


contract ArbitrageBLUSDTest is Test {
    uint256 constant MIN_BLUSD_PROFIT = 100e18;
    uint256 constant MIN_USDC_PROFIT = 100e18;
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint160 constant MIN_SQRT_RATIO = 4295128739;

    IERC20 constant blusdToken = IERC20(0xB9D7DdDca9a4AC480991865EfEf82E01273F79C3);
    IERC20 constant usdcToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    BLUSDArb blusdArb;

    Accounts accounts;
    address public /* immutable */ accountA;

    function setUp() public {
        accounts = new Accounts();
        accountA = vm.addr(uint256(accounts.accountsPks(0)));

        blusdArb = new BLUSDArb();
    }

    function _arbitrageBLUSDUSDC(uint256 initialBLUSDAmount) internal {
        emit log_named_decimal_uint("initialBLUSDAmount", initialBLUSDAmount, 18);

        uint256 senderBalanceBefore = blusdToken.balanceOf(accountA);

        /*
        uint256 ethAmount = uniswapQuoter.quoteExactInputSingle(
            BLUSD_TOKEN_ADRESS,
            WETH_TOKEN_ADRESS,
            3000,
            initialBLUSDAmount,
            MIN_SQRT_RATIO + 1
        );
        emit log_named_decimal_uint("ETH amount", ethAmount, 18);
        emit log_named_decimal_uint("Uniswap BLUSD/ETH effective price", ethAmount * 1e18 / initialBLUSDAmount, 18);
        emit log_named_decimal_uint("Uniswap ETH/BLUSD effective price", initialBLUSDAmount * 1e18 / ethAmount, 18);

        uint256 usdtAmount = threeCrypto.get_dy(2, 0, ethAmount);
        uint256 lusdAmount = lusdCrv.get_dy_underlying(3, 0, usdtAmount);
        emit log_named_decimal_uint("BLUSD Reserve USDT amount", usdtAmount, 6);
        emit log_named_decimal_uint("BLUSD Reserve LUSD amount", lusdAmount, 18);
        */

        vm.startPrank(accountA);
        blusdArb.swapBLUSDToUSDC(initialBLUSDAmount, accountA, 0);
        vm.stopPrank();
        uint256 senderBalanceAfter = blusdToken.balanceOf(accountA);

        emit log_named_decimal_uint("senderBalanceBefore", senderBalanceBefore, 18);
        emit log_named_decimal_uint("senderBalanceAfter", senderBalanceAfter, 18);

        uint256 gain = senderBalanceAfter - senderBalanceBefore;
        emit log_named_decimal_uint("gain", gain, 18);
        assertGt(gain, MIN_BLUSD_PROFIT, "Not enough profit");
    }

    function _arbitrageUSDCBLUSD(uint256 initialUSDCAmount) internal {
        emit log_named_decimal_uint("initialUSDCAmount", initialUSDCAmount, 6);

        uint256 senderBalanceBefore = usdcToken.balanceOf(accountA);

        vm.startPrank(accountA);
        blusdArb.swapUSDCToBLUSD(initialUSDCAmount, accountA, 0);
        vm.stopPrank();
        uint256 senderBalanceAfter = usdcToken.balanceOf(accountA);

        emit log_named_decimal_uint("senderBalanceBefore", senderBalanceBefore, 18);
        emit log_named_decimal_uint("senderBalanceAfter", senderBalanceAfter, 18);

        uint256 gain = senderBalanceAfter - senderBalanceBefore;
        emit log_named_decimal_uint("gain", gain, 18);
        assertGt(gain, MIN_USDC_PROFIT, "Not enough profit");
    }

    function testArbitrageBLUSDToUSDC() external {
        _arbitrageBLUSDUSDC(1000e18);
    }

    function testArbitrageUSDCToBLUSD() external {
        _arbitrageUSDCBLUSD(1000e6);
    }
}
