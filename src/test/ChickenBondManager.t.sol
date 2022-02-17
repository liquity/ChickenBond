// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../ChickenBondManager.sol";
import "../BondNFT.sol"; 
// import "../Interfaces/ILUSDToken.sol";
import "./TestContracts/LUSDTokenTester.sol";
import "./TestContracts/Accounts.sol";
import "../ExternalContracts/MockYearnLUSDVault.sol";
import "../console.sol";

interface Vm {
    function warp(uint256 x) external;
    function expectRevert(bytes calldata) external;
    function addr(uint256) external returns (address);
    function prank(address sender) external;
    function startPrank(address sender) external;
    function stopPrank() external;
    function expectRevert() external;
}

address constant CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

contract ChickenBondManagerTest is DSTest {
    Accounts accounts;

    ChickenBondManager chickenBondManager;
    BondNFT bondNFT;
    LUSDTokenTester lusdToken;
    MockYearnLUSDVault yearnLUSDVault;

    Vm vm = Vm(CHEATCODE_ADDRESS);

    address[] accountsList;
    address public A;
    address public B;
    address public C;
    
    function setUp() public {
        accounts = new Accounts();
        createAccounts();

        lusdToken = new LUSDTokenTester(ZERO_ADDRESS,ZERO_ADDRESS, ZERO_ADDRESS);

        (A, B, C) = (accountsList[0], accountsList[1], accountsList[2]);
       
        // Give some LUSD to test accounts
        lusdToken.unprotectedMint(A, 100e18);
        lusdToken.unprotectedMint(B, 100e18);
        lusdToken.unprotectedMint(C, 100e18);

        // Check accounts are funded
        assertTrue(lusdToken.balanceOf(A) == 100e18);
        assertTrue(lusdToken.balanceOf(B) == 100e18);
        assertTrue(lusdToken.balanceOf(C) == 100e18);
    
        yearnLUSDVault = new MockYearnLUSDVault();
        yearnLUSDVault.setAddresses(address(lusdToken));

        chickenBondManager = new ChickenBondManager();

        // TODO: choose conventional name and symbol for NFT contract 
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");
        chickenBondManager.initialize(address(bondNFT), address(lusdToken), address(yearnLUSDVault));
        bondNFT.setAddresses(address(chickenBondManager));
    }

    function createAccounts() public {
        address[10] memory tempAccounts;
        for (uint256 i = 0; i < accounts.getAccountsCount(); i++) {
            tempAccounts[i] = vm.addr(uint256(accounts.accountsPks(i)));
        }

        accountsList = tempAccounts;
    }

    // --- Deployment / setup tests ---

    function testSetupSetsBondNFTAddressInCBM() public {
        assertTrue(address(chickenBondManager.bondNFT()) == address(bondNFT));
    }

    function testSetupSetsCMBAddressInBondNFT() public {
        assertTrue(bondNFT.chickenBondManagerAddress() == address(chickenBondManager));
    }

    function testYearnLUSDVaultHasInfiniteLUSDApproval() public {
       uint allowance = lusdToken.allowance(address(chickenBondManager), address(yearnLUSDVault));
       assertEq(allowance, 2**256 - 1);
    }

    function testYearnCurveLUSDVaultHasInfiniteLUSDApproval() public {
        // TODO
    }

    // --- createBond tests ---

    function testFirstCreateBondIncreasesTotalPendingLUSD() public {
        // Get initial pending LUSD
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        
        // Confirm initial total pending LUSD is 0
        assertTrue(totalPendingLUSDBefore == 0);

        // A approves the system for LUSD transfer and creates the bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);

        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDAfter == 25e18);
    }

    function testCreateBondIncreasesTotalPendingLUSD() public {
        // First, A creates an initial bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        vm.stopPrank();
  
        // Get initial pending LUSD
        uint256 pendingLUSDBefore = chickenBondManager.totalPendingLUSD();
       
        // B creates the bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(10e18);

        vm.stopPrank();
        
        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDAfter == 35e18);
    }

    function testCreateBondReducesLUSDBalanceOfBonder() public {
        // Get A balance before
        uint balanceBefore = lusdToken.balanceOf(A);

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check A balance has reduced by correct amount
        uint balanceAfter = lusdToken.balanceOf(A);
        assertEq(balanceBefore - 10e18, balanceAfter);
    }

    function testFirstCreateBondIncreasesTheBondNFTTokenSupply() public {
        // Get NFT token supply before
        uint tokenSupplyBefore = bondNFT.getCurrentTokenSupply();

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check NFT token supply after has increased by 1
        uint tokenSupplyAfter = bondNFT.getCurrentTokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTTokenSupply() public {
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();
        
        // Get NFT token supply before
        uint tokenSupplyBefore = bondNFT.getCurrentTokenSupply();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check NFT token supply after has increased by 1
        uint tokenSupplyAfter = bondNFT.getCurrentTokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesBonderNFTBalance() public {
        // Check A has no NFTs
        uint A_NFTBalanceBefore = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceBefore, 0);

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();
        
        // Check A now has one NFT
        uint A_NFTBalanceAfter = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceAfter, 1);
    }

     function testCreateBondMintsBondNFTWithCorrectIDToBonder() public {
        // Expect revert when checking the owner of id #2, since it hasnt been minted
        vm.expectRevert("ERC721: owner query for nonexistent token");
        address ownerOfID1Before = bondNFT.ownerOf(2);
       
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check tokenSupply == 1 and A has NFT id #1
        assertEq(bondNFT.getCurrentTokenSupply(),  1);
        address ownerOfID0 = bondNFT.ownerOf(1);
        assertEq(ownerOfID0, A);
        
        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check owner of NFT id #2 is B
        address ownerOfID1After = bondNFT.ownerOf(2);
        assertEq(ownerOfID1After, B);
    }

    function testCreateBondTransfersLUSDToYearnVault() public {
        // Get Yearn vault balance before
        uint256 yearnVaultBalanceBefore = lusdToken.balanceOf(address(yearnLUSDVault));

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        uint256 yearnVaultBalanceAfter = lusdToken.balanceOf(address(yearnLUSDVault));

        assertEq(yearnVaultBalanceAfter, yearnVaultBalanceBefore + 10e18);
    }
}
