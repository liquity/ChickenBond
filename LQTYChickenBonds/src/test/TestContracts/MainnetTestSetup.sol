// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../Interfaces/IBancorNetwork.sol";
import "../../Interfaces/jar.sol";
import "./BaseTest.sol";
import "./Interfaces/ICurveFactory.sol";
import "../../Interfaces/ICurveLiquidityGaugeV4.sol";


contract MainnetTestSetup is BaseTest {
    // Mainnet addresses
    address constant MAINNET_LQTY_TOKEN_ADDRESS = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address constant MAINNET_PICKLE_JAR = 0x65B2532474f717D5A8ba38078B78106D56118bbb;
    //address constant MAINNET_BANCOR_NETWORK_ADDRESS = 0xeEF417e1D5CC832e619ae18D2F140De2999dD4fB;
    address constant MAINNET_BANCOR_NETWORK_INFO_ADDRESS = 0x8E303D296851B320e6a697bAcB979d13c9D6E760;
    address constant MAINNET_BNT_TOKEN_ADDRESS = 0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C;
    address constant MAINNET_CURVE_V2_FACTORY_ADDRESS = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;

    // uint256 constant MAINNET_PINNED_BLOCK = 1647873904; // ~3pm UTC 21/03/2022
    uint256 constant MAINNET_PINNED_BLOCK =  1655208977;

    function setUp() public {
        //pinBlock(MAINNET_PINNED_BLOCK);
        pinBlock(block.timestamp);

        accounts = new Accounts();
        createAccounts();

        // Grab deployed mainnet LQTYToken
        lqtyToken = IERC20(MAINNET_LQTY_TOKEN_ADDRESS);

        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);

        // Give some LQTY to test accounts
        deal(address(lqtyToken), A, 1e24, false);
        deal(address(lqtyToken), B, 1e24, false);
        deal(address(lqtyToken), C, 1e24, false);

        // Check accounts are funded
        assertTrue(lqtyToken.balanceOf(A) == 1e24);
        assertTrue(lqtyToken.balanceOf(B) == 1e24);
        assertTrue(lqtyToken.balanceOf(C) == 1e24);

        // Connect to deployed Pickle LQTY Vault
        pickleJar = IJar(MAINNET_PICKLE_JAR);

        // Connect to deployed Bancor Network
        bancorNetworkInfo = IBancorNetworkInfo(MAINNET_BANCOR_NETWORK_INFO_ADDRESS);
        //bancorNetwork = IBancorNetwork(MAINNET_BANCOR_NETWORK_ADDRESS);
        bancorNetwork = IBancorNetwork(bancorNetworkInfo.network());
        bntLQTYToken = IERC20(bancorNetworkInfo.poolToken(MAINNET_LQTY_TOKEN_ADDRESS));
        bntToken = IERC20(MAINNET_BNT_TOKEN_ADDRESS);

        // Deploy core ChickenBonds system
        bLQTYToken = new BLQTYToken("bLQTYToken", "BLQTY");

        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT("LQTYBondNFT", "LQTYBOND");

        // Deploy LQTY/bLQTY AMM Curve V2 pool and LiquidityGauge V4
        ICurveFactory curveFactory = ICurveFactory(MAINNET_CURVE_V2_FACTORY_ADDRESS);
        address[4] memory bLQTYCurvePoolCoins = [address(bLQTYToken), address(lqtyToken), address(0), address(0)];
        address bLQTYCurvePoolAddress = curveFactory.deploy_plain_pool(
            "bLQTY_LQTY",               // name
            "bLQTYLQTYC",              // symbol
            bLQTYCurvePoolCoins,        // coins
            1000,                       // A
            4000000,                    // fee
            1,                          // asset type
            1                           // implementation idx
        );
        address curveLiquidityGaugeAddress = curveFactory.deploy_gauge(bLQTYCurvePoolAddress);
        curveLiquidityGauge = ICurveLiquidityGaugeV4(curveLiquidityGaugeAddress);

        LQTYChickenBondManager.ExternalAdresses memory externalContractAddresses = LQTYChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lqtyTokenAddress: address(lqtyToken),
            bLQTYTokenAddress: address(bLQTYToken),
            pickleJarAddress: address(pickleJar),
            bancorNetworkInfoAddress: address(bancorNetworkInfo),
            curveLiquidityGaugeAddress: curveLiquidityGaugeAddress
        });

        chickenBondManager = new LQTYChickenBondManagerWrap(
            externalContractAddresses,
            TARGET_AVERAGE_AGE_SECONDS,        // _targetAverageAgeSeconds
            INITIAL_ACCRUAL_PARAMETER,         // _initialAccrualParameter
            MINIMUM_ACCRUAL_PARAMETER,         // _minimumAccrualParameter
            ACCRUAL_ADJUSTMENT_RATE,           // _accrualAdjustmentRate
            ACCRUAL_ADJUSTMENT_PERIOD_SECONDS, // _accrualAdjustmentPeriodSeconds
            CHICKEN_IN_AMM_FEE                 // _CHICKEN_IN_AMM_FEE
        );

        // Add LQTY as reward token for Curve Liquidity Gauge, and set ChickenBondManager as distributor
        vm.startPrank(curveFactory.admin());
        curveLiquidityGauge.add_reward(address(lqtyToken), address(chickenBondManager));
        vm.stopPrank();

        bondNFT.setAddresses(address(chickenBondManager));
        bLQTYToken.setAddresses(address(chickenBondManager));

        // Log some current blockchain state
        console.log(block.timestamp, "block.timestamp");
        console.log(block.number, "block.number");
        console.log(lqtyToken.totalSupply(), "Total LQTY supply");
        console.log(address(lqtyToken), "LQTYToken address");
        console.log(address(chickenBondManager), "ChickenBondManager address");
        console.log(address(bLQTYToken), "bLQTYToken address");
        console.log(address(bondNFT), "BondNFT address");
        console.log(address(bancorNetworkInfo), "Bancor Network Info address");
        console.log(address(bancorNetwork), "Bancor Network address");
        console.log(bancorNetworkInfo.poolToken(MAINNET_LQTY_TOKEN_ADDRESS), "Bancor Network LQTY pool token");
        console.log(address(pickleJar), "Pickle Jar address");
        console.log(bLQTYCurvePoolAddress, "Curve bLQTY/LQTY pool address");
        console.log(curveLiquidityGaugeAddress, "Curve Liquidity Gauge address");
    }

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }
}
