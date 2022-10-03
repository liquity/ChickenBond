

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./BaseTest.sol";
import "../../ExternalContracts/MockBAMMSPVault.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import "../../ExternalContracts/MockYearnRegistry.sol";
import  "../../ExternalContracts/MockCurvePool.sol";
import  "../../ExternalContracts/MockCurveLiquidityGauge.sol";
import "../../ExternalContracts/MockTroveManager.sol";
import "../../ExternalContracts/MockLQTYStaking.sol";
import "../../ExternalContracts/MockPickleJar.sol";
import "../../ExternalContracts/MockCurveGaugeController.sol";
import "./LUSDTokenTester.sol";


contract DevTestSetup is BaseTest {
    function setUp() public virtual {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        // Deploy a mock token then assign its interface
        LUSDTokenTester mockLUSDToken = new LUSDTokenTester(ZERO_ADDRESS,ZERO_ADDRESS, ZERO_ADDRESS);
        lusdToken = IERC20Permit(address(mockLUSDToken));

        (A, B, C, D, yearnGovernanceAddress) = (accountsList[0], accountsList[1], accountsList[2], accountsList[3], accountsList[9]);

        // Give some LUSD to test accounts
        uint256 initialLUSDAmount = 2000e18;
        deal(address(lusdToken), A, initialLUSDAmount);
        deal(address(lusdToken), B, initialLUSDAmount);
        deal(address(lusdToken), C, initialLUSDAmount);
        deal(address(lusdToken), D, initialLUSDAmount);

        // Check accounts are funded
        assertEq(lusdToken.balanceOf(A), initialLUSDAmount);
        assertEq(lusdToken.balanceOf(B), initialLUSDAmount);
        assertEq(lusdToken.balanceOf(C), initialLUSDAmount);
        assertEq(lusdToken.balanceOf(D), initialLUSDAmount);

        // Deploy external mock contracts, and assign corresponding interfaces
        MockCurvePool mockCurvePool = new MockCurvePool("LUSD-3CRV Pool", "LUSD3CRV-f");
        mockCurvePool.setAddresses(address(lusdToken));
        curvePool = ICurvePool(address(mockCurvePool));

        MockCurvePool mockCurveBasePool = new MockCurvePool("3CRV Pool", "3CRV");
        curveBasePool = ICurvePool(address(mockCurveBasePool));

        MockBAMMSPVault mockBAMMSPVault = new MockBAMMSPVault(address(lusdToken));
        bammSPVault = IBAMM(address(mockBAMMSPVault));

        MockYearnVault mockYearnCurveVault = new MockYearnVault("Curve LUSD Pool yVault", "yvCurve-LUSD");
        mockYearnCurveVault.setAddresses(address(curvePool));
        yearnCurveVault = IYearnVault(address(mockYearnCurveVault));

        MockYearnRegistry mockYearnRegistry = new MockYearnRegistry(
            address(yearnCurveVault),
            address(curvePool)
        );
        yearnRegistry = IYearnRegistry(address(mockYearnRegistry));

        // Deploy core ChickenBonds system
        bLUSDToken = new BLUSDToken("bLUSDToken", "BLUSD");

        BondNFT.LiquityDataAddresses memory liquityDataAddresses = BondNFT.LiquityDataAddresses({
            troveManagerAddress: address(new MockTroveManager()),
            lqtyToken: address(new ERC20("LQTY token", "LQTY")),
            lqtyStaking: address(new MockLQTYStaking()),
            pickleLQTYJar: address(new MockPickleJar("pickling LQTY", "pLQTY")),
            pickleLQTYFarm: address(new ERC20("Pickle Farm LTQY", "pfLQTY")),
            curveGaugeController: address(new MockCurveGaugeController()),
            curveLUSD3CRVGauge: address(0x1337),
            curveLUSDFRAXGauge: address(0x1337)
        });

        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT(
            "LUSDBondNFT",
            "LUSDBOND",
            address(0),
            BOND_NFT_TRANSFER_LOCKOUT_PERIOD_SECONDS,
            liquityDataAddresses
        );

        // Deploy LUSD/bLUSD AMM LP Rewards contract
        curveLiquidityGauge = ICurveLiquidityGaugeV5(address(new MockCurveLiquidityGauge()));

        ChickenBondManager.ExternalAdresses memory externalContractAddresses = ChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lusdTokenAddress: address(lusdToken),
            bLUSDTokenAddress: address(bLUSDToken),
            curvePoolAddress: address(curvePool),
            curveBasePoolAddress: address(curveBasePool),
            bammSPVaultAddress: address(bammSPVault),
            yearnCurveVaultAddress: address(yearnCurveVault),
            yearnRegistryAddress: address(yearnRegistry),
            curveLiquidityGaugeAddress: address(curveLiquidityGauge),
            yearnGovernanceAddress: yearnGovernanceAddress
        });

        ChickenBondManager.Params memory params = ChickenBondManager.Params({
            targetAverageAgeSeconds: TARGET_AVERAGE_AGE_SECONDS,
            initialAccrualParameter: INITIAL_ACCRUAL_PARAMETER,
            minimumAccrualParameter: MINIMUM_ACCRUAL_PARAMETER,
            accrualAdjustmentRate: ACCRUAL_ADJUSTMENT_RATE,
            accrualAdjustmentPeriodSeconds: ACCRUAL_ADJUSTMENT_PERIOD_SECONDS,
            chickenInAMMFee: CHICKEN_IN_AMM_FEE,
            curveDepositDydxThreshold: 1e18,
            curveWithdrawalDxdyThreshold: 1e18,
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

        bondNFT.setAddresses(address(chickenBondManager));
        bLUSDToken.setAddresses(address(chickenBondManager));

        CHICKEN_IN_AMM_FEE = chickenBondManager.CHICKEN_IN_AMM_FEE();
        MIN_BLUSD_SUPPLY = chickenBondManager.MIN_BLUSD_SUPPLY();
        MIN_BOND_AMOUNT = chickenBondManager.MIN_BOND_AMOUNT();
        SHIFTER_DELAY = chickenBondManager.SHIFTER_DELAY();
        SHIFTER_WINDOW = chickenBondManager.SHIFTER_WINDOW();
    }
}
