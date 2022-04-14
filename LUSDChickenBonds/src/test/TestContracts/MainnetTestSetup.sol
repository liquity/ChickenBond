// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// import "../../console.sol";
import "./BaseTest.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import  "../../ExternalContracts/MockCurvePool.sol";
import "uniswapV2/interfaces/IUniswapV2Factory.sol";


contract MainnetTestSetup is BaseTest {
    // Mainnet addresses
    address constant MAINNET_LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant MAINNET_3CRV_TOKEN_ADDRESS = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address constant MAINNET_YEARN_LUSD_VAULT_ADDRESS = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC;
    address constant MAINNET_YEARN_CURVE_VAULT_ADDRESS = 0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6;
    address constant MAINNET_CURVE_POOL_ADDRESS = 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA;
    address constant MAINNET_YEARN_REGISTRY_ADDRESS = 0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804;
    address constant MAINNET_YEARN_GOVERNANCE_ADDRESS = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address constant MAINNET_UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
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
        tip(address(lusdToken), A, 100e18);
        tip(address(lusdToken), B, 100e18);
        tip(address(lusdToken), C, 100e18);
    
        // Check accounts are funded
        assertTrue(lusdToken.balanceOf(A) == 100e18);
        assertTrue(lusdToken.balanceOf(B) == 100e18);
        assertTrue(lusdToken.balanceOf(C) == 100e18);

        // Connect to deployed Yearn LUSD Vault
        yearnLUSDVault = IYearnVault(MAINNET_YEARN_LUSD_VAULT_ADDRESS);

        // Connect to deployed LUSD-3CRV Curve pool, and Yearn LUSD-3CRV vault
        curvePool = ICurvePool(MAINNET_CURVE_POOL_ADDRESS);
        yearnCurveVault = IYearnVault(MAINNET_YEARN_CURVE_VAULT_ADDRESS);

        yearnRegistry = IYearnRegistry(MAINNET_YEARN_REGISTRY_ADDRESS);

        yearnGovernanceAddress = MAINNET_YEARN_GOVERNANCE_ADDRESS;

        // Deploy core ChickenBonds system
        sLUSDToken = new SLUSDToken("sLUSDToken", "SLUSD");

        // TODO: choose conventional name and symbol for NFT contract 
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");

        // Deploy LUSD/sLUSD AMM LP Rewards staking contract
        IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(MAINNET_UNISWAP_V2_FACTORY_ADDRESS);
        address uniswapPairAddress = uniswapV2Factory.createPair(address(lusdToken), address(sLUSDToken));
        sLUSDLPRewardsStaking = new Unipool(address(lusdToken), uniswapPairAddress);

        chickenBondManager = new ChickenBondManagerWrap(
            address(bondNFT),
            address(lusdToken), 
            address(curvePool),
            address(yearnLUSDVault),
            address(yearnCurveVault),
            address(sLUSDToken),
            address(yearnRegistry),
            address(sLUSDLPRewardsStaking),
            CHICKEN_IN_AMM_TAX
        );

        bondNFT.setAddresses(address(chickenBondManager));
        sLUSDToken.setAddresses(address(chickenBondManager));

        // Log some current blockchain state
        console.log(block.timestamp, "block.timestamp");
        console.log(block.number, "block.number");
        console.log(lusdToken.totalSupply(), "Total LUSD supply");
        console.log(address(lusdToken), "LUSDToken address");
        console.log(address(yearnLUSDVault), "Yearn LUSD vault address");
        console.log(address(yearnCurveVault), "Yearn Curve vault address");
        console.log(address(curvePool), "Curve pool address");  
        console.log(address(chickenBondManager), "ChickenBondManager address");  
        console.log(address(sLUSDToken), "sLUSDToken address"); 
        console.log(address(bondNFT), "BondNFT address");
    }

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }
}
