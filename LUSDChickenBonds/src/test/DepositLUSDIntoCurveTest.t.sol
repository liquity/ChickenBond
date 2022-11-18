pragma solidity ^0.8.11;

import "./TestContracts/Accounts.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";


interface ICurve {
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns(uint);
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external;
}


contract DepositLUSDIntoCurveTest is Test {
    //uint256 constant depositAmount = 2e24; // 2M
    address constant LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    IERC20 constant lusdToken = IERC20(LUSD_TOKEN_ADDRESS);
    ICurve constant lusdCrv = ICurve(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    ICurve constant _3pool = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    Accounts accounts;
    address public /* immutable */ accountA;
    uint256 initialLUSDPrice;
    uint256 lastDeposit;

    function setUp() public {
        accounts = new Accounts();
        accountA = vm.addr(uint256(accounts.accountsPks(0)));
        initialLUSDPrice = lusdCrv.get_dy_underlying(0, 1, 1e18);
        emit log_named_decimal_uint("Current LUSD price", initialLUSDPrice, 18);
        console.log();
    }

    function _testDepositIntoCurve(uint256 _depositAmount) internal {
        console.log();
        emit log_named_decimal_uint("Depositing (M)", _depositAmount / 1e21, 3);

        uint256 depositAmount = _depositAmount - lastDeposit;
        lastDeposit = _depositAmount;

        deal(LUSD_TOKEN_ADDRESS, accountA, depositAmount);

        vm.startPrank(accountA);
        lusdToken.approve(address(lusdCrv), depositAmount);
        lusdCrv.add_liquidity([depositAmount, 0], 0);
        vm.stopPrank();

        uint256 finalLUSDPrice = lusdCrv.get_dy_underlying(0, 1, 1e18);
        emit log_named_decimal_uint("Final LUSD price", finalLUSDPrice, 18);
        emit log_named_decimal_uint("LUSD price reduction %", initialLUSDPrice * 1e20 / finalLUSDPrice - 1e20, 18);
        console.log();
    }

    function testDepositIntoCurve() external {
        _testDepositIntoCurve(300e21); // 300k
        _testDepositIntoCurve(500e21); // 500k
        _testDepositIntoCurve(1e24);   // 1M
        _testDepositIntoCurve(2e24);   // 2M
        _testDepositIntoCurve(3e24);   // 3M
        _testDepositIntoCurve(4e24);   // 4M
        _testDepositIntoCurve(5e24);   // 5M
        _testDepositIntoCurve(10e24);  // 10M
    }
}
