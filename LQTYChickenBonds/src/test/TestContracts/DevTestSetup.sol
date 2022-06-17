// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./BaseTest.sol";
import  "./MockERC20.sol";
import  "../ExternalContracts/MockPickleJar.sol";
import  "../ExternalContracts/MockBancorNetwork.sol";
import  "../ExternalContracts/MockBancorNetworkInfo.sol";
import  "../ExternalContracts/MockCurveLiquidityGaugeV4.sol";


contract DevTestSetup is BaseTest {
    function setUp() public virtual {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        // Deploy a mock token then assign its interface
        lqtyToken = new MockERC20("LQTY", "Liquity token");

        (A, B, C) = (accountsList[0], accountsList[1], accountsList[2]);

        // Give some LQTY to test accounts
        uint256 initialLQTYAmount = 2000e18;
        deal(address(lqtyToken), A, initialLQTYAmount, true);
        deal(address(lqtyToken), B, initialLQTYAmount, true);
        deal(address(lqtyToken), C, initialLQTYAmount, true);

        // Check accounts are funded
        assertEq(lqtyToken.balanceOf(A), initialLQTYAmount);
        assertEq(lqtyToken.balanceOf(B), initialLQTYAmount);
        assertEq(lqtyToken.balanceOf(C), initialLQTYAmount);

        // Deploy external mock contracts, and assign corresponding interfaces
        pickleJar = new MockPickleJar(MockERC20(address(lqtyToken)));
        bancorNetwork = new MockBancorNetwork();
        bancorNetworkInfo = new MockBancorNetworkInfo(bancorNetwork, lqtyToken);
        bntToken = new ERC20PresetMinterPauser("Bancor Network Token", "BNT");
        deal(address(bntToken), address(bancorNetwork), 1e27, true);

        // Deploy core ChickenBonds system
        bLQTYToken = new BLQTYToken("bLQTYToken", "BLQTY");

        // TODO: choose conventional name and symbol for NFT contract
        bondNFT = new BondNFT("LQTYBondNFT", "LQTYBOND");

        // Deploy LQTY/bLQTY AMM LP Rewards contract
        curveLiquidityGauge = ICurveLiquidityGaugeV4(address(new MockCurveLiquidityGaugeV4()));

        LQTYChickenBondManager.ExternalAdresses memory externalContractAddresses = LQTYChickenBondManager.ExternalAdresses({
            bondNFTAddress: address(bondNFT),
            lqtyTokenAddress: address(lqtyToken),
            bLQTYTokenAddress: address(bLQTYToken),
            pickleJarAddress: address(pickleJar),
            bancorNetworkInfoAddress: address(bancorNetworkInfo),
            curveLiquidityGaugeAddress: address(curveLiquidityGauge)
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

        bondNFT.setAddresses(address(chickenBondManager));
        bLQTYToken.setAddresses(address(chickenBondManager));
    }
}
