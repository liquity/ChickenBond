// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BaseTest.sol";
import "./Interfaces/ICurveCryptoFactory.sol";
import "../../Interfaces/ICurveCryptoPool.sol";
import "./Interfaces/ICurveGaugeManagerProxy.sol";
import "../../Interfaces/ICurveLiquidityGaugeV5.sol";


contract MainnetTestSetup is BaseTest {
    // Mainnet addresses
    address constant MAINNET_LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant MAINNET_LQTY_TOKEN_ADDRESS = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    address constant MAINNET_LIQUITY_SP_ADDRESS = 0x66017D22b0f8556afDd19FC67041899Eb65a21bb;
    address constant MAINNET_LIQUITY_TROVE_MANAGER_ADDRESS = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2;
    address constant MAINNET_LIQUITY_STAKING_ADDRESS = 0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d;
    address constant MAINNET_PICKLE_LQTY_JAR_ADDRESS = 0x65B2532474f717D5A8ba38078B78106D56118bbb;
    address constant MAINNET_PICKLE_LQTY_FARM_ADDRESS = 0xA7BC844a76e727Ec5250f3849148c21F4b43CeEA;
    address constant MAINNET_3CRV_TOKEN_ADDRESS = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address constant MAINNET_YEARN_CURVE_VAULT_ADDRESS = 0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6;
    address constant MAINNET_CURVE_POOL_ADDRESS = 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA;
    address constant MAINNET_CURVE_BASE_POOL_ADDRESS = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address constant MAINNET_YEARN_REGISTRY_ADDRESS = 0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804;
    address constant MAINNET_YEARN_GOVERNANCE_ADDRESS = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address constant MAINNET_CURVE_V2_FACTORY_ADDRESS = 0xF18056Bbd320E96A48e3Fbf8bC061322531aac99;
    //address constant MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS = 0xd05Ad7fb0CDb39AaAA1407564dad0EC78d30d564;
    address constant MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS = 0x9f99FDe2ED3997EAfE52b78E3981b349fD2Eb8C9;
    address constant MAINNET_CURVE_GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    address constant MAINNET_CURVE_GAUGE_LUSD_3CRV = 0x9B8519A9a00100720CCdC8a120fBeD319cA47a14;
    address constant MAINNET_CURVE_GAUGE_LUSD_FRAX = 0x389Fc079a15354E9cbcE8258433CC0F85B755A42;
    address constant MAINNET_CHAINLINK_ETH_USD_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant MAINNET_CHAINLINK_LUSD_USD_ADDRESS = 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0;
    address constant MAINNET_BPROTOCOL_FEE_POOL_ADDRESS = 0x7095F0B91A1010c11820B4E263927835A4CF52c9;
    // uint256 constant MAINNET_PINNED_BLOCK = 1647873904; // ~3pm UTC 21/03/2022
    uint256 constant MAINNET_PINNED_BLOCK =  1648476300;
    uint256 BOOTSTRAP_PERIOD_CHICKEN_IN;
    uint256 BOOTSTRAP_PERIOD_REDEEM;
    uint256 BOOTSTRAP_PERIOD_SHIFT;
    uint256 CBMDeploymentTime;
    IERC20 bLUSDCurveToken;
    ICurveCryptoPool bLUSDCurvePool;
    address curveGaugeManagerAddress;

    function setUp() public {
        // pinBlock(MAINNET_PINNED_BLOCK);
        pinBlock(block.timestamp);

        accounts = new Accounts();
        createAccounts();

        // Grab deployed mainnet LUSDToken
        lusdToken = IERC20Permit(MAINNET_LUSD_TOKEN_ADDRESS);

        _3crvToken = IERC20(MAINNET_3CRV_TOKEN_ADDRESS);

        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);
        curveGaugeManagerAddress = accountsList[8];

        // Give some LUSD to test accounts
        deal(address(lusdToken), A, 1e24);
        deal(address(lusdToken), B, 1e24);
        deal(address(lusdToken), C, 1e24);
        deal(address(lusdToken), D, 1e24);

        // Check accounts are funded
        assertTrue(lusdToken.balanceOf(A) == 1e24);
        assertTrue(lusdToken.balanceOf(B) == 1e24);
        assertTrue(lusdToken.balanceOf(C) == 1e24);
        assertTrue(lusdToken.balanceOf(D) == 1e24);

        bammSPVault = IBAMM(
            deployCode(
                "BAMM.sol:BAMM",
                abi.encode(
                    MAINNET_CHAINLINK_ETH_USD_ADDRESS,  // _priceAggregator
                    MAINNET_CHAINLINK_LUSD_USD_ADDRESS, // _lusd2UsdPriceAggregator
                    MAINNET_LIQUITY_SP_ADDRESS,         // _SP
                    MAINNET_LUSD_TOKEN_ADDRESS,         // _LUSD
                    MAINNET_LQTY_TOKEN_ADDRESS,         // _LQTY
                    uint256(400),                       // _maxDiscount
                    MAINNET_BPROTOCOL_FEE_POOL_ADDRESS, // _feePool
                    address(0),                         // _fronEndTag
                    uint256(0)                          // _timelockDuration
                )
            )
        );

        // Connect to deployed LUSD-3CRV Curve pool, and Yearn LUSD-3CRV vault
        curvePool = ICurvePool(MAINNET_CURVE_POOL_ADDRESS);
        curveBasePool = ICurvePool(MAINNET_CURVE_BASE_POOL_ADDRESS);
        yearnCurveVault = IYearnVault(MAINNET_YEARN_CURVE_VAULT_ADDRESS);

        yearnRegistry = IYearnRegistry(MAINNET_YEARN_REGISTRY_ADDRESS);

        yearnGovernanceAddress = MAINNET_YEARN_GOVERNANCE_ADDRESS;
        liquitySPAddress = MAINNET_LIQUITY_SP_ADDRESS;

        // Deploy core ChickenBonds system
        bLUSDToken = new BLUSDToken("bLUSDToken", "BLUSD");

        BondNFT.LiquityDataAddresses memory liquityDataAddresses = BondNFT.LiquityDataAddresses({
            troveManagerAddress: MAINNET_LIQUITY_TROVE_MANAGER_ADDRESS,
            lqtyToken: MAINNET_LQTY_TOKEN_ADDRESS,
            lqtyStaking: MAINNET_LIQUITY_STAKING_ADDRESS,
            pickleLQTYJar: MAINNET_PICKLE_LQTY_JAR_ADDRESS,
            pickleLQTYFarm: MAINNET_PICKLE_LQTY_FARM_ADDRESS,
            curveGaugeController: MAINNET_CURVE_GAUGE_CONTROLLER,
            curveLUSD3CRVGauge: MAINNET_CURVE_GAUGE_LUSD_3CRV,
            curveLUSDFRAXGauge: MAINNET_CURVE_GAUGE_LUSD_FRAX
        });
        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT(
            "LUSDBondNFT",
            "LUSDBOND",
            address(0),
            BOND_NFT_TRANSFER_LOCKOUT_PERIOD_SECONDS,
            liquityDataAddresses
        );

        // Deploy LUSD/bLUSD AMM Curve V2 pool and LiquidityGauge V4
        ICurveCryptoFactory curveFactory = ICurveCryptoFactory(MAINNET_CURVE_V2_FACTORY_ADDRESS);
        address[2] memory bLUSDCurvePoolCoins = [address(bLUSDToken), address(lusdToken)];

        bLUSDCurvePool = ICurveCryptoPool(
            curveFactory.deploy_pool(
                "bLUSD_LUSD",        // _name
                "bLUSDLUSDC",        // _symbol
                bLUSDCurvePoolCoins, // _coins
                4000,                // A
                0.000145e18,         // gamma
                0.5e8,               // mid_fee (%)
                1.0e8,               // out_fee (%)
                0.000002e18,         // allowed_extra_profit
                0.0023e18,           // fee_gamma
                0.000146e18,         // adjustment_step
                50e8,                // admin_fee (%)
                1 days,              // ma_half_time
                1.2e18               // initial_price (token1 / token2)
            )
        );
        bLUSDCurveToken = IERC20(bLUSDCurvePool.token());

        ICurveGaugeManagerProxy curveGaugeManagerProxy = ICurveGaugeManagerProxy(MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS);
        address curveLiquidityGaugeAddress = curveGaugeManagerProxy.deploy_gauge(address(bLUSDCurvePool), curveGaugeManagerAddress);
        curveLiquidityGauge = ICurveLiquidityGaugeV5(curveLiquidityGaugeAddress);

        ChickenBondManager.ExternalAdresses memory externalContractAddresses = ChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lusdTokenAddress: address(lusdToken),
            bLUSDTokenAddress: address(bLUSDToken),
            curvePoolAddress: address(curvePool),
            curveBasePoolAddress: address(curveBasePool),
            bammSPVaultAddress: address(bammSPVault),
            yearnCurveVaultAddress: address(yearnCurveVault),
            yearnRegistryAddress: address(yearnRegistry),
            curveLiquidityGaugeAddress: curveLiquidityGaugeAddress,
            yearnGovernanceAddress: yearnGovernanceAddress
        });

        ChickenBondManager.Params memory params = ChickenBondManager.Params({
            targetAverageAgeSeconds: TARGET_AVERAGE_AGE_SECONDS,
            initialAccrualParameter: INITIAL_ACCRUAL_PARAMETER,
            minimumAccrualParameter: MINIMUM_ACCRUAL_PARAMETER,
            accrualAdjustmentRate: ACCRUAL_ADJUSTMENT_RATE,
            accrualAdjustmentPeriodSeconds: ACCRUAL_ADJUSTMENT_PERIOD_SECONDS,
            chickenInAMMFee: CHICKEN_IN_AMM_FEE,
            curveDepositDydxThreshold: 10004e14, // 1.0004
            curveWithdrawalDxdyThreshold: 10004e14, // 1.0004
            bootstrapPeriodChickenIn: 7 days,
            bootstrapPeriodRedeem: 7 days,
            bootstrapPeriodShift: 90 days,
            shifterDelay: 60 minutes,
            shifterWindow: 10 minutes,
            minBLUSDSupply: 1e18,
            minBondAmount: 100e18,
            nftRandomnessDivisor: 1000e18,
            //redemptionFeeBeta: 2,
            //redemptionFeeMinuteDecayFactor: 999037758833783000 // Half-life of 12h
            redemptionFeeBeta: type(uint256).max,  // This will make division zero
            redemptionFeeMinuteDecayFactor: 0 // decPow will always return 0 for base 0 => decayFactor = 0 => decayed base = 0
        });

        chickenBondManager = new ChickenBondManagerWrap(externalContractAddresses, params);

        CHICKEN_IN_AMM_FEE = chickenBondManager.CHICKEN_IN_AMM_FEE();
        MIN_BLUSD_SUPPLY = chickenBondManager.MIN_BLUSD_SUPPLY();
        MIN_BOND_AMOUNT = chickenBondManager.MIN_BOND_AMOUNT();
        BOOTSTRAP_PERIOD_CHICKEN_IN = chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN();
        BOOTSTRAP_PERIOD_REDEEM = chickenBondManager.BOOTSTRAP_PERIOD_REDEEM();
        BOOTSTRAP_PERIOD_SHIFT = chickenBondManager.BOOTSTRAP_PERIOD_SHIFT();
        SHIFTER_DELAY = chickenBondManager.SHIFTER_DELAY();
        SHIFTER_WINDOW = chickenBondManager.SHIFTER_WINDOW();
        
        CBMDeploymentTime = chickenBondManager.deploymentTimestamp();

        // Add LUSD as reward token for Curve Liquidity Gauge, and set ChickenBondManager as distributor
        vm.startPrank(curveGaugeManagerAddress);
        curveGaugeManagerProxy.add_reward(curveLiquidityGaugeAddress, address(lusdToken), address(chickenBondManager));
        vm.stopPrank();

        bondNFT.setAddresses(address(chickenBondManager));
        bLUSDToken.setAddresses(address(chickenBondManager));
        bammSPVault.setChicken(address(chickenBondManager));

        // Log some current blockchain state
        console.log(block.timestamp, "block.timestamp");
        console.log(block.number, "block.number");
        console.log(lusdToken.totalSupply(), "Total LUSD supply");
        console.log(address(lusdToken), "LUSDToken address");
        console.log(address(bammSPVault), "B.Protocol LUSD vault address");
        console.log(address(yearnCurveVault), "Yearn Curve vault address");
        console.log(address(curvePool), "Curve pool address");
        console.log(address(chickenBondManager), "ChickenBondManager address");
        console.log(address(bLUSDToken), "bLUSDToken address");
        console.log(address(bondNFT), "BondNFT address");
        console.log(address(bLUSDCurvePool), "Curve bLUSD/LUSD pool address");
        console.log(curveLiquidityGaugeAddress, "Curve Liquidity Gauge address");
    }

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }
}
