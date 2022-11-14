pragma solidity ^0.8.11;


import "./TestContracts/Accounts.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";


interface LQTYArb {
    function swap(uint lqtyQty, address reserve, address lqtyDest, uint minLqtyProfit) external payable returns(uint);
}

interface GemSeller {
    function maxDiscount() external view returns(uint);
    function lusdVirtualBalance() external view returns(uint);
    function A() external view returns(uint);
    function fetchGem2EthPrice() external view returns(uint);
    function fetchEthPrice() external view returns(uint);
    function gemToUSD(uint gemQty, uint gem2EthPrice, uint eth2UsdPrice) external pure returns(uint);
    function USDToGem(uint lusdQty, uint gem2EthPrice, uint eth2UsdPrice) external pure returns(uint);
    function getSwapGemAmount(uint lusdQty) external view returns(uint gemAmount, uint feeLusdAmount);
    function getReturn(uint xQty, uint xBalance, uint yBalance, uint A) external pure returns(uint);
    function compensateForLusdDeviation(uint gemAmount) external view returns(uint newGemAmount);
}

interface LQTYReserve {
    function getSwapAmount(uint ethAmount) external view returns(uint lqtyAmount);
}

interface IUniswapQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

interface ICurve {
    function get_dy(uint i, uint j, uint dx) external view returns(uint);
    function get_dy_underlying(int128 i, int128 j, uint dx) external view returns(uint);
    function exchange(uint i, uint j, uint dx, uint minDy, bool useEth) external payable;
    function exchange_underlying(int128 i, int128 j, uint dx, uint minDy) external returns(uint);
}


contract HarvestBProtocolTest is Test {
    uint256 constant MIN_LQTY_PROFIT = 100e18;
    uint160 constant MIN_SQRT_RATIO = 4295128739;

    address constant LQTY_TOKEN_ADRESS = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address constant WETH_TOKEN_ADRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BAMM_ADDRESS = 0x896d8a30C32eAd64f2e1195C2C8E0932Be7Dc20B;
    IERC20 constant lqtyToken = IERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    LQTYArb constant lqtyArb = LQTYArb(0xf9A0e641c98f964b1c732661FaB9D5B96af28D49);
    GemSeller constant gemSeller = GemSeller(0x7605aaA45344F91315E0C596Ab679159784F8b7b);
    LQTYReserve constant lqtyReserve = LQTYReserve(0x4f73ad319193320ED20eeFAEFb8F30B89b05b8B6);
    IUniswapQuoter constant uniswapQuoter = IUniswapQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    ICurve constant threeCrypto = ICurve(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    ICurve constant lusdCrv = ICurve(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);

    Accounts accounts;
    address public /* immutable */ accountA;

    uint256 public /* immutable */ maxDiscount;
    uint256 public /* immutable */ lusdVirtualBalance;
    uint256 public /* immutable */ paramA;

    function setUp() public {
        accounts = new Accounts();
        accountA = vm.addr(uint256(accounts.accountsPks(0)));
        maxDiscount = gemSeller.maxDiscount();
        lusdVirtualBalance = gemSeller.lusdVirtualBalance();
        paramA = gemSeller.A();
    }

    function testHarvest() external {
        emit log_named_decimal_uint("B.Protocol max discount %", maxDiscount, 2);
        emit log_named_decimal_uint("B.Protocol LUSD virtual balance", lusdVirtualBalance, 18);

        uint256 bammLQTYBalance = lqtyToken.balanceOf(BAMM_ADDRESS);
        emit log_named_decimal_uint("bammLQTYBalance", bammLQTYBalance, 18);

        deal(address(lqtyToken), accountA, bammLQTYBalance);
        uint256 senderBalanceBefore = lqtyToken.balanceOf(accountA);

        uint256 ethAmount = uniswapQuoter.quoteExactInputSingle(
            LQTY_TOKEN_ADRESS,
            WETH_TOKEN_ADRESS,
            3000,
            bammLQTYBalance,
            MIN_SQRT_RATIO + 1
        );
        emit log_named_decimal_uint("ETH amount", ethAmount, 18);
        emit log_named_decimal_uint("Uniswap LQTY/ETH effective price", ethAmount * 1e18 / bammLQTYBalance, 18);
        emit log_named_decimal_uint("Uniswap ETH/LQTY effective price", bammLQTYBalance * 1e18 / ethAmount, 18);

        uint usdtAmount = threeCrypto.get_dy(2, 0, ethAmount);
        uint lusdAmount = lusdCrv.get_dy_underlying(3, 0, usdtAmount);
        emit log_named_decimal_uint("LQTY Reserve USDT amount", usdtAmount, 6);
        emit log_named_decimal_uint("LQTY Reserve LUSD amount", lusdAmount, 18);

        uint256 eth2usdPrice = gemSeller.fetchEthPrice();
        uint256 gem2ethPrice = gemSeller.fetchGem2EthPrice();
        emit log_named_decimal_uint("GemSeller ETH price (Chainlink)", eth2usdPrice, 18);
        emit log_named_decimal_uint("GemSeller LQTY/ETH price (Chainlink)", gem2ethPrice, 18);
        emit log_named_decimal_uint("GemSeller ETH/LQTY price (Chainlink)", 1e36 / gem2ethPrice, 18);

        uint gemUsdValue = gemSeller.gemToUSD(bammLQTYBalance, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller LQTY $ value", gemUsdValue, 18);
        uint lusdToLQTY = gemSeller.USDToGem(lusdAmount, gem2ethPrice, eth2usdPrice);
        uint256 lqtyWithDiscount = lusdToLQTY * (10000 + maxDiscount) / 10000;
        emit log_named_decimal_uint("GemSeller LUSD -> LQTY", lusdToLQTY, 18);
        emit log_named_decimal_uint("GemSeller max return (LQTY + discount)", lqtyWithDiscount, 18);

        uint usdReturn = gemSeller.getReturn(lusdAmount, lusdVirtualBalance, lusdVirtualBalance + (gemUsdValue * 2), paramA);
        uint basicGemReturn = gemSeller.USDToGem(usdReturn, gem2ethPrice, eth2usdPrice);
        uint256 returnWithDeviation = gemSeller.compensateForLusdDeviation(basicGemReturn);
        emit log_named_decimal_uint("GemSeller USD return", usdReturn, 18);
        emit log_named_decimal_uint("GemSeller Basic return", basicGemReturn, 18);
        emit log_named_decimal_uint("GemSeller Basic return + LUSD deviation", returnWithDeviation, 18);
        emit log_named_decimal_uint("GemSeller LUSD deviation", returnWithDeviation * 1e18 / basicGemReturn, 18);

        (uint256 gemSellerLQTYAmount,) = gemSeller.getSwapGemAmount(lusdAmount);
        emit log_named_decimal_uint("LQTY Reserve LQTY amount", gemSellerLQTYAmount, 18);
        //emit log_named_decimal_uint("LQTY Reserve LQTY amount", lqtyReserve.getSwapAmount(ethAmount), 18);


        vm.startPrank(accountA);
        uint256 lqtyAmount = bammLQTYBalance;
        emit log_named_decimal_uint("lqtyAmount", lqtyAmount, 18);
        lqtyArb.swap(lqtyAmount, address(lqtyReserve), accountA, 0);
        vm.stopPrank();
        // To avoid stack too deep:
        //uint256 senderBalanceAfter = lqtyToken.balanceOf(accountA);

        emit log_named_decimal_uint("senderBalanceBefore", senderBalanceBefore, 18);
        emit log_named_decimal_uint("senderBalanceAfter", lqtyToken.balanceOf(accountA), 18);

        uint256 gain = lqtyToken.balanceOf(accountA) - senderBalanceBefore;
        emit log_named_decimal_uint("gain", gain, 18);
        assertGt(gain, MIN_LQTY_PROFIT, "Not enough profit");
    }
}
