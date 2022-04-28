

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../Dependencies/Uniswap/UniswapV2Factory.sol";
import "../Dependencies/Uniswap/UniswapV2Router.sol";

import "./BaseTest.sol";
// import "../../utils/console.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import "../../ExternalContracts/MockYearnRegistry.sol";
import  "../../ExternalContracts/MockCurvePool.sol";
import "./LUSDTokenTester.sol";


contract DevTestSetup is BaseTest {
    function setUp() public {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        // Deploy a mock token then assign its interface
        LUSDTokenTester mockLUSDToken = new LUSDTokenTester(ZERO_ADDRESS,ZERO_ADDRESS, ZERO_ADDRESS);
        lusdToken = IERC20(address(mockLUSDToken));

        (A, B, C) = (accountsList[0], accountsList[1], accountsList[2]);

        // Give some LUSD to test accounts
        tip(address(lusdToken), A, 100e18);
        tip(address(lusdToken), B, 100e18);
        tip(address(lusdToken), C, 100e18);
        
        // Check accounts are funded
        assertEq(lusdToken.balanceOf(A), 100e18);
        assertEq(lusdToken.balanceOf(B), 100e18);
        assertEq(lusdToken.balanceOf(C), 100e18);

        // Deploy external mock contracts, and assign corresponding interfaces
        MockCurvePool mockCurvePool = new MockCurvePool("LUSD-3CRV Pool", "LUSD3CRV-f");
        mockCurvePool.setAddresses(address(lusdToken));
        curvePool = ICurvePool(address(mockCurvePool));

        MockYearnVault mockYearnLUSDVault = new MockYearnVault("LUSD yVault", "yvLUSD");
        mockYearnLUSDVault.setAddresses(address(lusdToken));
        yearnLUSDVault = IYearnVault(address(mockYearnLUSDVault));

        MockYearnVault mockYearnCurveVault = new MockYearnVault("Curve LUSD Pool yVault", "yvCurve-LUSD");
        mockYearnCurveVault.setAddresses(address(curvePool));
        yearnCurveVault = IYearnVault(address(mockYearnCurveVault));

        MockYearnRegistry mockYearnRegistry = new MockYearnRegistry(
            address(yearnLUSDVault),
            address(yearnCurveVault),
            address(lusdToken),
            address(curvePool)
        );
        yearnRegistry = IYearnRegistry(address(mockYearnRegistry));

        // Deploy core ChickenBonds system
        sLUSDToken = new SLUSDToken("sLUSDToken", "SLUSD");

        // TODO: choose conventional name and symbol for NFT contract 
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");

        // Deploy LUSD/sLUSD AMM LP Rewards staking contract
        IERC20 uniToken = new ERC20("Uniswap LP Token", "UNI"); // mock Uniswap LP token
        sLUSDLPRewardsStaking = new Unipool(address(lusdToken), address(uniToken));

        // Uniswap contracts
        uniswapV2Factory = new UniswapV2Factory(address(0));
        UniswapV2Router uniswapRouter = new UniswapV2Router(address(uniswapV2Factory), address(new ERC20("Wrapped ETH", "WETH")));

        chickenBondManager = new ChickenBondManagerWrap(
            address(bondNFT),
            address(lusdToken),
            address(curvePool),
            address(yearnLUSDVault),
            address(yearnCurveVault),
            address(sLUSDToken),
            address(yearnRegistry),
            address(sLUSDLPRewardsStaking),
            address(uniswapRouter),
            CHICKEN_IN_AMM_TAX
        );

        bondNFT.setAddresses(address(chickenBondManager));
        sLUSDToken.setAddresses(address(chickenBondManager));
    }
}
