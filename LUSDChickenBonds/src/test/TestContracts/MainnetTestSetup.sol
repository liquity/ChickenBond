// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// import "../../utils/console.sol";
import "./BaseTest.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import "../../ExternalContracts/MockCurvePool.sol";
import "./Interfaces/ICurveFactory.sol";
import "../../Interfaces/ICurveLiquidityGaugeV4.sol";


contract MainnetTestSetup is BaseTest {
    // Mainnet addresses
    address constant MAINNET_LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant MAINNET_LIQUITY_SP_ADDRESS = 0x66017D22b0f8556afDd19FC67041899Eb65a21bb;
    address constant MAINNET_3CRV_TOKEN_ADDRESS = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address constant MAINNET_YEARN_LUSD_VAULT_ADDRESS = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC;
    address constant MAINNET_YEARN_CURVE_VAULT_ADDRESS = 0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6;
    address constant MAINNET_CURVE_POOL_ADDRESS = 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA;
    address constant MAINNET_YEARN_REGISTRY_ADDRESS = 0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804;
    address constant MAINNET_YEARN_GOVERNANCE_ADDRESS = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address constant MAINNET_CURVE_V2_FACTORY_ADDRESS = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;
    // uint256 constant MAINNET_PINNED_BLOCK = 1647873904; // ~3pm UTC 21/03/2022
    uint256 constant MAINNET_PINNED_BLOCK =  1648476300;

    function setUp() public {
        // pinBlock(MAINNET_PINNED_BLOCK);
        pinBlock(block.timestamp);

        accounts = new Accounts();
        createAccounts();

        // Grab deployed mainnet LUSDToken
        lusdToken = IERC20(MAINNET_LUSD_TOKEN_ADDRESS);

        _3crvToken = IERC20(MAINNET_3CRV_TOKEN_ADDRESS);

        (A, B, C, D) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3]);

        // Give some LUSD to test accounts
        tip(address(lusdToken), A, 1e24);
        tip(address(lusdToken), B, 1e24);
        tip(address(lusdToken), C, 1e24);

        // Check accounts are funded
        assertTrue(lusdToken.balanceOf(A) == 1e24);
        assertTrue(lusdToken.balanceOf(B) == 1e24);
        assertTrue(lusdToken.balanceOf(C) == 1e24);

        // Connect to deployed Yearn LUSD Vault
        yearnSPVault = IYearnVault(MAINNET_YEARN_LUSD_VAULT_ADDRESS);

        // Connect to deployed LUSD-3CRV Curve pool, and Yearn LUSD-3CRV vault
        curvePool = ICurvePool(MAINNET_CURVE_POOL_ADDRESS);
        yearnCurveVault = IYearnVault(MAINNET_YEARN_CURVE_VAULT_ADDRESS);

        yearnRegistry = IYearnRegistry(MAINNET_YEARN_REGISTRY_ADDRESS);

        yearnGovernanceAddress = MAINNET_YEARN_GOVERNANCE_ADDRESS;
        liquitySPAddress = MAINNET_LIQUITY_SP_ADDRESS;

        // Deploy core ChickenBonds system
        sLUSDToken = new SLUSDToken("sLUSDToken", "SLUSD");

        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");

        lusdSilo = new LUSDSilo();

        // Deploy LUSD/sLUSD AMM Curve V2 pool and LiquidityGauge V4
        ICurveFactory curveFactory = ICurveFactory(MAINNET_CURVE_V2_FACTORY_ADDRESS);
        address[4] memory sLUSDCurvePoolCoins = [address(sLUSDToken), address(lusdToken), address(0), address(0)];
        address sLUSDCurvePoolAddress = curveFactory.deploy_plain_pool(
            "sLUSD_LUSD",               // name
            "sLUSDLUSDC",              // symbol
            sLUSDCurvePoolCoins,        // coins
            1000,                       // A
            4000000,                    // fee
            1,                          // asset type
            1                           // implementation idx
        );
        address curveLiquidityGaugeAddress = curveFactory.deploy_gauge(sLUSDCurvePoolAddress);
        curveLiquidityGauge = ICurveLiquidityGaugeV4(curveLiquidityGaugeAddress);

        ChickenBondManager.ExternalAdresses memory externalContractAddresses = ChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lusdTokenAddress: address(lusdToken),
            sLUSDTokenAddress: address(sLUSDToken),
            curvePoolAddress: address(curvePool),
            yearnSPVaultAddress: address(yearnSPVault),
            yearnCurveVaultAddress: address(yearnCurveVault),
            yearnRegistryAddress: address(yearnRegistry),
            curveLiquidityGaugeAddress: curveLiquidityGaugeAddress,
            yearnGovernanceAddress: yearnGovernanceAddress,
            lusdSiloAddress: address(lusdSilo)
        });

        chickenBondManager = new ChickenBondManagerWrap(
            externalContractAddresses,
            TARGET_AVERAGE_AGE_SECONDS,        // _targetAverageAgeSeconds
            INITIAL_ACCRUAL_PARAMETER,         // _initialAccrualParameter
            MINIMUM_ACCRUAL_PARAMETER,         // _minimumAccrualParameter
            ACCRUAL_ADJUSTMENT_RATE,           // _accrualAdjustmentRate
            ACCRUAL_ADJUSTMENT_PERIOD_SECONDS, // _accrualAdjustmentPeriodSeconds
            CHICKEN_IN_AMM_FEE                 // _CHICKEN_IN_AMM_FEE
        );

        // Add LUSD as reward token for Curve Liquidity Gauge, and set ChickenBondManager as distributor
        vm.startPrank(curveFactory.admin());
        curveLiquidityGauge.add_reward(address(lusdToken), address(chickenBondManager));
        vm.stopPrank();

        bondNFT.setAddresses(address(chickenBondManager));
        sLUSDToken.setAddresses(address(chickenBondManager));
        lusdSilo.initialize(address(chickenBondManager));

        // Log some current blockchain state
        console.log(block.timestamp, "block.timestamp");
        console.log(block.number, "block.number");
        console.log(lusdToken.totalSupply(), "Total LUSD supply");
        console.log(address(lusdToken), "LUSDToken address");
        console.log(address(yearnSPVault), "Yearn LUSD vault address");
        console.log(address(yearnCurveVault), "Yearn Curve vault address");
        console.log(address(curvePool), "Curve pool address");
        console.log(address(chickenBondManager), "ChickenBondManager address");
        console.log(address(sLUSDToken), "sLUSDToken address");
        console.log(address(bondNFT), "BondNFT address");
        console.log(sLUSDCurvePoolAddress, "Curve sLUSD/LUSD pool address");
        console.log(curveLiquidityGaugeAddress, "Curve Liquidity Gauge address");
    }

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }
}
