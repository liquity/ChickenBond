pragma solidity ^0.8.11;

import "./TestContracts/Accounts.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";


interface ICurve {
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external;
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function calc_withdraw_one_coin(uint256 burn_amount, int128 i) external returns (uint256);
}

interface ICurve2 {
    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns(uint256);
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
}


contract SwapLUSDToBLUSDTest is Test {
    address constant LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant LUSD_3CRV_ADDRESS = 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA;
    IERC20 constant lusdToken = IERC20(LUSD_TOKEN_ADDRESS);
    ICurve constant lusdCrv = ICurve(LUSD_3CRV_ADDRESS);
    IERC20 constant lusd3CRVLPToken = IERC20(LUSD_3CRV_ADDRESS);
    ICurve2 constant bLUSDPool = ICurve2(0x74ED5d42203806c8CDCf2F04Ca5F60DC777b901c);

    Accounts accounts;
    address public /* immutable */ accountA;
    uint256 initialBLUSDPrice;
    uint256 lastSwap;

    function setUp() public {
        accounts = new Accounts();
        accountA = vm.addr(uint256(accounts.accountsPks(0)));
        initialBLUSDPrice = bLUSDPool.get_dy(0, 1, 1e18) * lusdCrv.calc_withdraw_one_coin(1e18, 0) / 1e18;
        console.log("Current block", block.number);
        console.log();
        emit log_named_decimal_uint("--> Current bLUSD/LUSD price", initialBLUSDPrice, 18);
        emit log_named_decimal_uint("bLUSD/LUSD3CRV pool price   ", bLUSDPool.get_dy(0, 1, 1e18), 18);
        emit log_named_decimal_uint("LUSD3CRV price              ", lusdCrv.calc_withdraw_one_coin(1e18, 0), 18);
        console.log();
    }

    function _testSwapLUSDToBLUSD(uint256 _swapAmount) internal {
        console.log();
        emit log_named_decimal_uint("Swapping (k)", _swapAmount / 1e18, 3);

        uint256 swapAmount = _swapAmount - lastSwap;
        lastSwap = _swapAmount;

        deal(LUSD_TOKEN_ADDRESS, accountA, swapAmount);

        vm.startPrank(accountA);
        // get LUSD-3CRV LP tokens by depositing single sided LUSD
        lusdToken.approve(address(lusdCrv), swapAmount);
        uint256 lusd3CRVBalanceBefore = lusd3CRVLPToken.balanceOf(accountA);
        lusdCrv.add_liquidity([swapAmount, 0], 0);
        // swap LUSD-3CRV to bLUSD
        uint256 lusd3CRVSwapAmount = lusd3CRVLPToken.balanceOf(accountA) - lusd3CRVBalanceBefore;
        //emit log_named_decimal_uint("lusd3CRVBalanceBefore", lusd3CRVBalanceBefore, 18);
        //emit log_named_decimal_uint("lusd3CRVBalanceAfter ", lusd3CRVLPToken.balanceOf(accountA), 18);
        lusd3CRVLPToken.approve(address(bLUSDPool), lusd3CRVSwapAmount);
        bLUSDPool.exchange(1, 0, lusd3CRVSwapAmount, 0);
        vm.stopPrank();

        uint256 finalBLUSDPrice = bLUSDPool.get_dy(0, 1, 1e18) * lusdCrv.calc_withdraw_one_coin(1e18, 0) / 1e18;
        emit log_named_decimal_uint("--> Final bLUSD/LUSD price", finalBLUSDPrice, 18);
        emit log_named_decimal_int("bLUSD price increase %    ", int256(finalBLUSDPrice * 1e20) / int256(initialBLUSDPrice) - int256(1e20), 18);
        //emit log_named_decimal_uint("bLUSD/LUSD3CRV pool price ", bLUSDPool.get_dy(0, 1, 1e18), 18);
        //emit log_named_decimal_uint("LUSD3CRV price            ", lusdCrv.calc_withdraw_one_coin(1e18, 0), 18);
        //emit log_named_decimal_uint("lusd3CRVSwapAmount        ", lusd3CRVSwapAmount, 18);
        console.log();
    }

    function testSwapLUSDToBLUSD() external {
        _testSwapLUSDToBLUSD(1e21);    // 1k
        _testSwapLUSDToBLUSD(5e21);    // 5k
        _testSwapLUSDToBLUSD(10e21);   // 10k
        _testSwapLUSDToBLUSD(20e21);   // 20k
        _testSwapLUSDToBLUSD(50e21);   // 50k
        _testSwapLUSDToBLUSD(100e21);  // 100k
    }
}
