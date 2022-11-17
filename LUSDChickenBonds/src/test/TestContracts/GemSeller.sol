pragma solidity ^0.8.14;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface AggregatorV3Interface {

    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface IGemOwner {
    function compound(uint lusdAmount) external;
}

interface GemSellerController {
    function setSeller(address _seller) external;
    function setPendingSeller(address _pendingSeller) external;
}


contract PriceFormula {
    function getSumFixedPoint(uint x, uint y, uint A) public pure returns(uint) {
        if(x == 0 && y == 0) return 0;

        uint sum = x + y;

        for(uint i = 0 ; i < 255 ; i++) {
            uint dP = sum;
            dP = dP * sum / ((x * 2) + 1);
            dP = dP * sum / ((y * 2) + 1);

            uint prevSum = sum;

            uint n = (A * 2 * (x + y) + (dP * 2)) * sum;
            uint d = (A * 2 - 1) * sum;
            sum = n / (d + (dP * 3));

            if(sum <= prevSum + 1 && prevSum <= sum + 1) break;
        }

        return sum;
    }

    function getReturn(uint xQty, uint xBalance, uint yBalance, uint A) public pure returns(uint) {
        uint sum = getSumFixedPoint(xBalance, yBalance, A);

        uint c = sum * sum / ((xQty + xBalance) * 2);
        c = c * sum / (A * 4);
        uint b = xQty + xBalance + (sum / (A * 2));
        uint yPrev = 0;
        uint y = sum;

        for(uint i = 0 ; i < 255 ; i++) {
            yPrev = y;
            uint n = y * y + c;
            uint d = y * 2 + b - sum;
            y = n / d;

            if(y <= yPrev + 1 && yPrev <= y + 1) break;
        }

        return yBalance - y - 1;
    }
}


contract GemSeller is PriceFormula {
    AggregatorV3Interface public immutable gem2ethPriceAggregator;
    AggregatorV3Interface public immutable eth2usdPriceAggregator;
    AggregatorV3Interface public immutable lusd2UsdPriceAggregator;
    IERC20 public immutable LUSD;
    IERC20 public immutable gem;
    address public immutable gemOwner;
    uint public immutable lusdVirtualBalance;
    address public immutable feePool;

    uint public constant MAX_FEE = 1000; // 10%
    uint public fee = 0; // fee in bps
    uint public A = 20;
    uint public constant MIN_A = 20;
    uint public constant MAX_A = 200;

    uint public immutable maxDiscount; // max discount in bips

    uint constant public PRECISION = 1e18;

    event RebalanceSwap(address indexed user, uint lusdAmount, uint gemAmount, uint timestamp);

    constructor(
        AggregatorV3Interface _gem2ethPriceAggregator,
        AggregatorV3Interface _eth2usdPriceAggregator,
        AggregatorV3Interface _lusd2UsdPriceAggregator,
        IERC20 _LUSD,
        IERC20 _gem,
        address _gemOwner,
        uint _lusdVirtualBalance,
        uint _maxDiscount,
        address _feePool
    )
    {
        gem2ethPriceAggregator = _gem2ethPriceAggregator;
        eth2usdPriceAggregator = _eth2usdPriceAggregator;
        lusd2UsdPriceAggregator = _lusd2UsdPriceAggregator;
        LUSD = _LUSD;
        gem = _gem;
        gemOwner = _gemOwner;
        lusdVirtualBalance = _lusdVirtualBalance;
        feePool = _feePool;
        maxDiscount = _maxDiscount;

        //require(_gem.decimals() == 18 && _LUSD.decimals() == 18, "only 18 decimals are supported");
    }

    function fetchPrice(AggregatorV3Interface feed) public view returns(uint) {
        uint chainlinkDecimals;
        uint chainlinkLatestAnswer;
        uint chainlinkTimestamp;

        // First, try to get current decimal precision:
        try feed.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkDecimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        // Secondly, try to get latest price data:
        try feed.latestRoundData() returns
        (
            uint80 /* roundId */,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkLatestAnswer = uint(answer);
            chainlinkTimestamp = timestamp;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return 0;
        }

        if(chainlinkTimestamp + 1 hours < block.timestamp) return 0; // price is down

        uint chainlinkFactor = 10 ** chainlinkDecimals;
        return chainlinkLatestAnswer * PRECISION / chainlinkFactor;
    }

    function fetchGem2EthPrice() public view returns(uint) {
        return fetchPrice(gem2ethPriceAggregator);
    }

    function fetchEthPrice() public view returns(uint) {
        return fetchPrice(eth2usdPriceAggregator);
    }

    function addBps(uint n, int bps) internal pure returns(uint) {
        require(bps <= 10000, "reduceBps: bps exceeds max");
        require(bps >= -10000, "reduceBps: bps exceeds min");

        return n * uint(10000 + bps) / 10000;
    }

    function compensateForLusdDeviation(uint gemAmount) public view returns(uint newGemAmount) {
        uint chainlinkDecimals;
        uint chainlinkLatestAnswer;

        // get current decimal precision:
        chainlinkDecimals = lusd2UsdPriceAggregator.decimals();

        // Secondly, try to get latest price data:
        (,int256 answer,,,) = lusd2UsdPriceAggregator.latestRoundData();
        chainlinkLatestAnswer = uint(answer);

        // adjust only if 1 LUSD > 1 USDC. If LUSD < USD, then we give a discount, and rebalance will happen anw
        if(chainlinkLatestAnswer > 10 ** chainlinkDecimals ) {
            newGemAmount = gemAmount * chainlinkLatestAnswer / (10 ** chainlinkDecimals);
        }
        else newGemAmount = gemAmount;
    }

    function gemToUSD(uint gemQty, uint gem2EthPrice, uint eth2UsdPrice) public pure returns(uint) {
        return gemQty * gem2EthPrice / PRECISION * eth2UsdPrice / PRECISION;
    }

    function USDToGem(uint lusdQty, uint gem2EthPrice, uint eth2UsdPrice) public pure returns(uint) {
        return lusdQty * PRECISION / gem2EthPrice * PRECISION / eth2UsdPrice;
    }

    function getSwapGemAmount(uint lusdQty) public view returns(uint gemAmount, uint feeLusdAmount) {
        console.log("");
        uint gemBalance  = gem.balanceOf(gemOwner);

        uint eth2usdPrice = fetchEthPrice();
        uint gem2ethPrice = fetchGem2EthPrice();
        if(eth2usdPrice == 0 || gem2ethPrice == 0) return (0, 0); // feed is down
        //console.log("GemSeller ETH price (Chainlink)", eth2usdPrice);
        //console.log("GemSeller LQTY/ETH price (Chainlink)", gem2ethPrice);
        //console.log("GemSeller ETH/LQTY price (Chainlink)", 1e36 / gem2ethPrice);

        uint gemUsdValue = gemToUSD(gemBalance, gem2ethPrice, eth2usdPrice);
        console.log("GemSeller LQTY $ value", gemUsdValue);
        uint maxReturn = addBps(USDToGem(lusdQty, gem2ethPrice, eth2usdPrice), int(maxDiscount));
        //uint256 lusdToLQTY = gemSeller.USDToGem(lusdQty, gemSeller.fetchGem2EthPrice(), gemSeller.fetchEthPrice());
        //console.log("GemSeller LUSD -> LQTY", lusdToLQTY);
        console.log("-> GemSeller max return (LQTY + discount)", maxReturn);

        uint xQty = lusdQty;
        uint xBalance = lusdVirtualBalance;
        uint yBalance = lusdVirtualBalance + (gemUsdValue * 2);

        uint usdReturn = getReturn(xQty, xBalance, yBalance, A);
        uint basicGemReturn = USDToGem(usdReturn, gem2ethPrice, eth2usdPrice);
        console.log("GemSeller USD return", usdReturn);
        console.log("GemSeller Basic return", basicGemReturn);

        uint256 returnWithDeviation = compensateForLusdDeviation(basicGemReturn);
        console.log("-> GemSeller Basic return + LUSD deviation", returnWithDeviation);
        console.log("GemSeller LUSD deviation", returnWithDeviation * 1e18 / basicGemReturn);

        if(gemBalance < basicGemReturn) basicGemReturn = gemBalance; // cannot give more than balance
        if(maxReturn < basicGemReturn) basicGemReturn = maxReturn;

        gemAmount = basicGemReturn;
        feeLusdAmount = addBps(lusdQty, int(fee)) - lusdQty;

        console.log(gemAmount, "gemAmount");
        console.log(feeLusdAmount, "feeLusdAmount");
    }

    // get gem in return to LUSD
    function swap(uint lusdAmount, uint minGemReturn, address payable dest) public returns(uint) {
        (uint gemAmount, uint feeAmount) = getSwapGemAmount(lusdAmount);

        require(gemAmount >= minGemReturn, "swap: low return");

        // transfer to gem owner and deposit lusd into the stability pool
        require(LUSD.transferFrom(msg.sender, gemOwner, lusdAmount - feeAmount), "swap: LUSD transfer failed");
        IGemOwner(gemOwner).compound(lusdAmount - feeAmount);

        // transfer fees to fee pool
        if(feeAmount > 0) require(LUSD.transferFrom(msg.sender, feePool, feeAmount), "swap: LUSD fee transfer failed");

        // send gem return to buyer
        require(gem.transferFrom(gemOwner, dest, gemAmount), "swap: LQTY transfer failed");

        emit RebalanceSwap(msg.sender, lusdAmount, gemAmount, block.timestamp);

        return gemAmount;
    }

    // kyber network reserve compatible function
    function trade(
        IERC20 /* srcToken */,
        uint256 srcAmount,
        IERC20 /* destToken */,
        address payable destAddress,
        uint256 /* conversionRate */,
        bool /* validate */
    ) external payable returns (bool) {
        return swap(srcAmount, 0, destAddress) > 0;
    }

    function getConversionRate(
        IERC20 /* src */,
        IERC20 /* dest */,
        uint256 srcQty,
        uint256 /* blockNumber */
    ) external view returns (uint256) {
        (uint gemQty, ) = getSwapGemAmount(srcQty);
        return gemQty * PRECISION / srcQty;
    }

    receive() external payable {}
}
