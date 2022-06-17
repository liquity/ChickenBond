

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./BaseTest.sol";
// import "../../utils/console.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import "../../ExternalContracts/MockYearnRegistry.sol";
import  "../../ExternalContracts/MockCurvePool.sol";
import  "../../ExternalContracts/MockCurveLiquidityGaugeV4.sol";
import "./LUSDTokenTester.sol";


contract DevTestSetup is BaseTest {
    function setUp() public virtual {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        // Deploy a mock token then assign its interface
        LUSDTokenTester mockLUSDToken = new LUSDTokenTester(ZERO_ADDRESS,ZERO_ADDRESS, ZERO_ADDRESS);
        lusdToken = IERC20(address(mockLUSDToken));

        (A, B, C, yearnGovernanceAddress) = (accountsList[0], accountsList[1], accountsList[2], accountsList[9]);

        // Give some LUSD to test accounts
        uint256 initialLUSDAmount = 2000e18;
        tip(address(lusdToken), A, initialLUSDAmount);
        tip(address(lusdToken), B, initialLUSDAmount);
        tip(address(lusdToken), C, initialLUSDAmount);

        // Check accounts are funded
        assertEq(lusdToken.balanceOf(A), initialLUSDAmount);
        assertEq(lusdToken.balanceOf(B), initialLUSDAmount);
        assertEq(lusdToken.balanceOf(C), initialLUSDAmount);

        // Deploy external mock contracts, and assign corresponding interfaces
        MockCurvePool mockCurvePool = new MockCurvePool("LUSD-3CRV Pool", "LUSD3CRV-f");
        mockCurvePool.setAddresses(address(lusdToken));
        curvePool = ICurvePool(address(mockCurvePool));

        MockCurvePool mockCurveBasePool = new MockCurvePool("3CRV Pool", "3CRV");
        curveBasePool = ICurvePool(address(mockCurveBasePool));

        MockYearnVault mockYearnLUSDVault = new MockYearnVault("LUSD yVault", "yvLUSD");
        mockYearnLUSDVault.setAddresses(address(lusdToken));
        yearnSPVault = IYearnVault(address(mockYearnLUSDVault));

        MockYearnVault mockYearnCurveVault = new MockYearnVault("Curve LUSD Pool yVault", "yvCurve-LUSD");
        mockYearnCurveVault.setAddresses(address(curvePool));
        yearnCurveVault = IYearnVault(address(mockYearnCurveVault));

        MockYearnRegistry mockYearnRegistry = new MockYearnRegistry(
            address(yearnSPVault),
            address(yearnCurveVault),
            address(lusdToken),
            address(curvePool)
        );
        yearnRegistry = IYearnRegistry(address(mockYearnRegistry));

        // Deploy core ChickenBonds system
        bLUSDToken = new BLUSDToken("bLUSDToken", "BLUSD");

        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");

        lusdSilo = new LUSDSilo();

        // Deploy LUSD/bLUSD AMM LP Rewards contract
        curveLiquidityGauge = ICurveLiquidityGaugeV4(address(new MockCurveLiquidityGaugeV4()));

        ChickenBondManager.ExternalAdresses memory externalContractAddresses = ChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lusdTokenAddress: address(lusdToken),
            bLUSDTokenAddress: address(bLUSDToken),
            curvePoolAddress: address(curvePool),
            curveBasePoolAddress: address(curveBasePool),
            yearnSPVaultAddress: address(yearnSPVault),
            yearnCurveVaultAddress: address(yearnCurveVault),
            yearnRegistryAddress: address(yearnRegistry),
            curveLiquidityGaugeAddress: address(curveLiquidityGauge),
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
            CHICKEN_IN_AMM_FEE,                // _CHICKEN_IN_AMM_FEE
            1e18,                              // _curveDepositDydxThreshold
            1e18                               // _curveWithdrawalDxdyThreshold
        );

        bondNFT.setAddresses(address(chickenBondManager));
        bLUSDToken.setAddresses(address(chickenBondManager));
    }
}
