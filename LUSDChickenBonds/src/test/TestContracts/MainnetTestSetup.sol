// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// import "../../console.sol";
import "./BaseTest.sol";
import "../../ExternalContracts/MockYearnVault.sol";
import  "../../ExternalContracts/MockCurvePool.sol";

contract MainnetTestSetup is BaseTest {
    // Mainnet addresses
    address constant MAINNET_LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant MAINNET_YEARN_LUSD_VAULT_ADDRESS = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC;
    address constant MAINNET_YEARN_REGISTRY_ADDRESS = 0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804;
    uint256 constant MAINNET_PINNED_BLOCK = 1647873904; // ~3pm UTC 21/03/2022

    function setUp() public {
        pinBlock(MAINNET_PINNED_BLOCK);

        accounts = new Accounts();
        createAccounts();

        // Grab deployed mainnet LUSDToken
        lusdToken = IERC20(MAINNET_LUSD_TOKEN_ADDRESS);

        (A, B, C) = (accountsList[0], accountsList[1], accountsList[2]);
       
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

        /* Deploy external mock contracts for Yearn Curve vault and Curve pool. TODO: replace with 
        * real deployed contracts, and write corresponding tests */
        MockCurvePool mockCurvePool = new MockCurvePool("LUSD-3CRV Pool", "LUSD3CRV-f");
        mockCurvePool.setAddresses(address(lusdToken));
        curvePool = ICurvePool(address(mockCurvePool));

        MockYearnVault mockYearnCurveVault = new MockYearnVault("Curve LUSD Pool yVault", "yvCurve-LUSD");
        mockYearnCurveVault.setAddresses(address(curvePool));
        yearnCurveVault = IYearnVault(address(mockYearnCurveVault));

        yearnRegistry = IYearnRegistry(MAINNET_YEARN_REGISTRY_ADDRESS);

        // Deploy core ChickenBonds system
        sLUSDToken = new SLUSDToken("sLUSDToken", "SLUSD");

        // TODO: choose conventional name and symbol for NFT contract 
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");
       
        chickenBondManager = new ChickenBondManager(
            address(bondNFT),
            address(lusdToken), 
            address(curvePool),
            address(yearnLUSDVault),
            address(yearnCurveVault),
            address(sLUSDToken),
            address(yearnRegistry)
        );

        bondNFT.setAddresses(address(chickenBondManager));
        sLUSDToken.setAddresses(address(chickenBondManager));

        // Log some current blockchain state
        console.log(block.timestamp, "block.timestamp");
        console.log(block.number, "block.number");
        console.log(lusdToken.totalSupply(), "Total LUSD supply");
    }

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }
}