pragma solidity ^0.8.11;


import "./TestContracts/Accounts.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import "../Tools/Interfaces/IUniswapQuoter.sol";
import "../Tools/LQTYWBTCArb.sol";
import "./TestContracts/GemSeller.sol";


interface LQTYArb {
    function swap(uint lqtyQty, address reserve, address lqtyDest, uint minLqtyProfit) external payable returns(uint);
}

interface LQTYReserve {
    function getSwapAmount(uint ethAmount) external view returns(uint lqtyAmount);
}

interface ICurve {
    function get_dy(uint i, uint j, uint dx) external view returns(uint);
    function get_dy_underlying(int128 i, int128 j, uint dx) external view returns(uint);
    function exchange(uint i, uint j, uint dx, uint minDy, bool useEth) external payable;
    function exchange_underlying(int128 i, int128 j, uint dx, uint minDy) external returns(uint);
}

contract HarvestBProtocolTest is Test {
    uint256 constant MIN_LQTY_PROFIT = 100e18;
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint160 constant MIN_SQRT_RATIO = 4295128739;

    address constant LUSD_TOKEN_ADRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant LQTY_TOKEN_ADRESS = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address constant WETH_TOKEN_ADRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_TOKEN_ADRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant BAMM_ADDRESS = 0x896d8a30C32eAd64f2e1195C2C8E0932Be7Dc20B;
    address constant BAMM_OWNER = 0xF15aBf59A957aeA1D81fc77F2634a2F55dD3b280;
    IERC20 constant lqtyToken = IERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    LQTYArb constant lqtyArb = LQTYArb(0xf9A0e641c98f964b1c732661FaB9D5B96af28D49);
    LQTYWBTCArb constant lqtyWBTCArb = LQTYWBTCArb(payable(0x0Ad96B511f501C1bdAb362C5c044EA8279846713));
    GemSeller constant gemSeller = GemSeller(payable(0x7605aaA45344F91315E0C596Ab679159784F8b7b));
    //LQTYWBTCArb constant lqtyWBTCArb;
    //GemSeller gemSeller;
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

        /* Use for debugging:
        gemSeller = new GemSeller(
            AggregatorV3Interface(0x1459dAC936578bbE620E2A22e3026cE9791F17D6),
            AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
            AggregatorV3Interface(0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0),
            IERC20(LUSD_TOKEN_ADRESS),
            IERC20(LQTY_TOKEN_ADRESS),
            BAMM_ADDRESS,
            5000000000000000000000000,
            400,
            0x7095F0B91A1010c11820B4E263927835A4CF52c9
        );
        lqtyWBTCArb = new LQTYWBTCArb(address(gemSeller));
        */
        //vm.startPrank(BAMM_OWNER);
        //GemSellerController(BAMM_ADDRESS).setPendingSeller(address(gemSeller));
        //vm.warp(block.timestamp + 604800);
        //GemSellerController(BAMM_ADDRESS).setSeller(address(gemSeller));
        //vm.stopPrank();

        maxDiscount = gemSeller.maxDiscount();
        lusdVirtualBalance = gemSeller.lusdVirtualBalance();
        paramA = gemSeller.A();
        //console.log(address(gemSeller.eth2usdPriceAggregator()), "ETH oracle");
    }

    function testHarvest() external {
        emit log_named_decimal_uint("B.Protocol max discount %", maxDiscount, 2);
        emit log_named_decimal_uint("B.Protocol LUSD virtual balance", lusdVirtualBalance, 18);

        uint256 initialLQTYAmount = lqtyToken.balanceOf(BAMM_ADDRESS);
        //uint256 initialLQTYAmount = 1000e18;
        emit log_named_decimal_uint("initialLQTYAmount", initialLQTYAmount, 18);

        uint256 senderBalanceBefore = lqtyToken.balanceOf(accountA);

        uint256 ethAmount = uniswapQuoter.quoteExactInputSingle(
            LQTY_TOKEN_ADRESS,
            WETH_TOKEN_ADRESS,
            3000,
            initialLQTYAmount,
            MIN_SQRT_RATIO + 1
        );
        emit log_named_decimal_uint("ETH amount", ethAmount, 18);
        emit log_named_decimal_uint("Uniswap LQTY/ETH effective price", ethAmount * 1e18 / initialLQTYAmount, 18);
        emit log_named_decimal_uint("Uniswap ETH/LQTY effective price", initialLQTYAmount * 1e18 / ethAmount, 18);

        uint256 usdtAmount = threeCrypto.get_dy(2, 0, ethAmount);
        uint256 lusdAmount = lusdCrv.get_dy_underlying(3, 0, usdtAmount);
        emit log_named_decimal_uint("LQTY Reserve USDT amount", usdtAmount, 6);
        emit log_named_decimal_uint("LQTY Reserve LUSD amount", lusdAmount, 18);

        uint256 eth2usdPrice = gemSeller.fetchEthPrice();
        uint256 gem2ethPrice = gemSeller.fetchGem2EthPrice();
        emit log_named_decimal_uint("GemSeller ETH price (Chainlink)", eth2usdPrice, 18);
        emit log_named_decimal_uint("GemSeller LQTY/ETH price (Chainlink)", gem2ethPrice, 18);
        emit log_named_decimal_uint("GemSeller ETH/LQTY price (Chainlink)", 1e36 / gem2ethPrice, 18);

        uint256 gemUsdValue = gemSeller.gemToUSD(initialLQTYAmount, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller LQTY $ value", gemUsdValue, 18);
        uint256 lusdToLQTY = gemSeller.USDToGem(lusdAmount, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller LUSD -> LQTY", lusdToLQTY, 18);
        emit log_named_decimal_uint("GemSeller max return (LQTY + discount)", lusdToLQTY * (10000 + maxDiscount) / 10000, 18);

        uint256 usdReturn = gemSeller.getReturn(lusdAmount, lusdVirtualBalance, lusdVirtualBalance + (gemUsdValue * 2), paramA);
        emit log_named_decimal_uint("GemSeller USD return", usdReturn, 18);
        uint256 basicGemReturn = gemSeller.USDToGem(usdReturn, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller Basic return", basicGemReturn, 18);
        uint256 returnWithDeviation = gemSeller.compensateForLusdDeviation(basicGemReturn);
        emit log_named_decimal_uint("GemSeller Basic return + LUSD deviation", returnWithDeviation, 18);
        emit log_named_decimal_uint("GemSeller LUSD deviation", returnWithDeviation * 1e18 / basicGemReturn, 18);

        (uint256 gemSellerLQTYAmount,) = gemSeller.getSwapGemAmount(lusdAmount);
        emit log_named_decimal_uint("LQTY Reserve LQTY amount", gemSellerLQTYAmount, 18);
        //emit log_named_decimal_uint("LQTY Reserve LQTY amount", lqtyReserve.getSwapAmount(ethAmount), 18);
        emit log_named_decimal_uint("initialLQTYAmount", initialLQTYAmount, 18);
        if (gemSellerLQTYAmount < initialLQTYAmount) {
            emit log_named_decimal_uint("Missing", initialLQTYAmount - gemSellerLQTYAmount, 18);
            emit log_named_decimal_uint("Missing %", initialLQTYAmount * 1e20 / gemSellerLQTYAmount - 1e20, 18);
        }

        vm.startPrank(accountA);
        lqtyArb.swap(initialLQTYAmount, address(lqtyReserve), accountA, 0);
        vm.stopPrank();
        // To avoid stack too deep:
        //uint256 senderBalanceAfter = lqtyToken.balanceOf(accountA);

        emit log_named_decimal_uint("senderBalanceBefore", senderBalanceBefore, 18);
        emit log_named_decimal_uint("senderBalanceAfter", lqtyToken.balanceOf(accountA), 18);

        uint256 gain = lqtyToken.balanceOf(accountA) - senderBalanceBefore;
        emit log_named_decimal_uint("gain", gain, 18);
        assertGt(gain, MIN_LQTY_PROFIT, "Not enough profit");
    }

    function testHarvestWBTC() external {
        emit log_named_decimal_uint("B.Protocol max discount %", maxDiscount, 2);
        emit log_named_decimal_uint("B.Protocol LUSD virtual balance", lusdVirtualBalance, 18);

        uint256 initialLQTYAmount = lqtyToken.balanceOf(BAMM_ADDRESS);
        //uint256 initialLQTYAmount = 1000e18;
        emit log_named_decimal_uint("initialLQTYAmount", initialLQTYAmount, 18);

        uint256 senderBalanceBefore = lqtyToken.balanceOf(accountA);

        uint256 wbtcAmount = uniswapQuoter.quoteExactInputSingle(
            LQTY_TOKEN_ADRESS,
            WBTC_TOKEN_ADRESS,
            10000,
            initialLQTYAmount,
            MAX_SQRT_RATIO - 1
        );
        emit log_named_decimal_uint("WBTC amount", wbtcAmount, 8);
        emit log_named_decimal_uint("Uniswap LQTY/WBTC effective price", wbtcAmount * 1e18 / initialLQTYAmount, 8);
        emit log_named_decimal_uint("Uniswap WBTC/LQTY effective price", initialLQTYAmount * 1e8 / wbtcAmount, 18);

        uint256 usdtAmount = threeCrypto.get_dy(1, 0, wbtcAmount);
        uint256 lusdAmount = lusdCrv.get_dy_underlying(3, 0, usdtAmount);
        emit log_named_decimal_uint("LQTY Reserve USDT amount", usdtAmount, 6);
        emit log_named_decimal_uint("LQTY Reserve LUSD amount", lusdAmount, 18);

        uint256 eth2usdPrice = gemSeller.fetchEthPrice();
        uint256 gem2ethPrice = gemSeller.fetchGem2EthPrice();
        emit log_named_decimal_uint("GemSeller ETH price (Chainlink)", eth2usdPrice, 18);
        emit log_named_decimal_uint("GemSeller LQTY/ETH price (Chainlink)", gem2ethPrice, 18);
        emit log_named_decimal_uint("GemSeller ETH/LQTY price (Chainlink)", 1e36 / gem2ethPrice, 18);

        uint256 gemUsdValue = gemSeller.gemToUSD(initialLQTYAmount, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller LQTY $ value", gemUsdValue, 18);
        uint256 lusdToLQTY = gemSeller.USDToGem(lusdAmount, gem2ethPrice, eth2usdPrice);
        emit log_named_decimal_uint("GemSeller LUSD -> LQTY", lusdToLQTY, 18);
        emit log_named_decimal_uint("GemSeller max return (LQTY + discount)", lusdToLQTY * (10000 + maxDiscount) / 10000, 18);

        uint256 usdReturn = gemSeller.getReturn(lusdAmount, lusdVirtualBalance, lusdVirtualBalance + (gemUsdValue * 2), paramA);
        uint256 basicGemReturn = gemSeller.USDToGem(usdReturn, gem2ethPrice, eth2usdPrice);
        uint256 returnWithDeviation = gemSeller.compensateForLusdDeviation(basicGemReturn);
        emit log_named_decimal_uint("GemSeller USD return", usdReturn, 18);
        emit log_named_decimal_uint("GemSeller Basic return", basicGemReturn, 18);
        emit log_named_decimal_uint("GemSeller Basic return + LUSD deviation", returnWithDeviation, 18);
        emit log_named_decimal_uint("GemSeller LUSD deviation", returnWithDeviation * 1e18 / basicGemReturn, 18);

        (uint256 gemSellerLQTYAmount,) = gemSeller.getSwapGemAmount(lusdAmount);
        emit log_named_decimal_uint("GemSeller LQTY amount", gemSellerLQTYAmount, 18);
        emit log_named_decimal_uint("initialLQTYAmount", initialLQTYAmount, 18);
        if (gemSellerLQTYAmount < initialLQTYAmount) {
            emit log_named_decimal_uint("Missing", initialLQTYAmount - gemSellerLQTYAmount, 18);
            emit log_named_decimal_uint("Missing %", initialLQTYAmount * 1e20 / gemSellerLQTYAmount - 1e20, 18);
        }

        vm.startPrank(accountA);
        lqtyWBTCArb.swap(initialLQTYAmount, accountA, 0);
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
