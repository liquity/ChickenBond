// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../ChickenBondManager.sol";
import "../BondNFT.sol"; 
import "./TestContracts/SLUSDTokenTester.sol";
import "./TestContracts/LUSDTokenTester.sol";
import "./TestContracts/Accounts.sol";
import "../ExternalContracts/MockYearnVault.sol";
import  "../ExternalContracts/MockCurvePool.sol";
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
    SLUSDToken sLUSDToken;
    LUSDTokenTester lusdToken;
    MockCurvePool curvePool;
    MockYearnVault yearnLUSDVault;
    MockYearnVault yearnCurveVault;

    Vm vm = Vm(CHEATCODE_ADDRESS);

    address[] accountsList;
    address public A;
    address public B;
    address public C;
    
    function setUp() public {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

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

        // Deploy external mock contracts
        curvePool = new MockCurvePool("LUSD-3CRV Pool", "LUSD3CRV-f");
        curvePool.setAddresses(address(lusdToken));

        yearnLUSDVault = new MockYearnVault("LUSD yVault", "yvLUSD");
        yearnLUSDVault.setAddresses(address(lusdToken));

        yearnCurveVault = new MockYearnVault("Curve LUSD Pool yVault", "yvCurve-LUSD");
        yearnCurveVault.setAddresses(address(curvePool));

        // Deploy core ChickenBonds system
        sLUSDToken = new SLUSDTokenTester("sLUSDToken", "SLUSD");

        // TODO: choose conventional name and symbol for NFT contract 
        bondNFT = new BondNFT("LUSDBondNFT", "LUSDBOND");
       
        chickenBondManager = new ChickenBondManager(
            address(bondNFT),
            address(lusdToken), 
            address(curvePool),
            address(yearnLUSDVault),
            address(yearnCurveVault),
            address(sLUSDToken)
        );

        bondNFT.setAddresses(address(chickenBondManager));
        sLUSDToken.setAddresses(address(chickenBondManager));
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

    function testCreateBondRecordsBondData() public {
        // A creates bond #1
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Confirm bond data for bond #2 is 0
        (uint B_bondedLUSD, uint B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);

        // Get current time
        uint currentTime = block.timestamp;

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check bonded amount and bond start time are now recorded for B's bond
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 10e18);
        assertEq(B_bondStartTime, currentTime);
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
        address ownerOfID2Before = bondNFT.ownerOf(2);
       
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check tokenSupply == 1 and A has NFT id #1
        assertEq(bondNFT.getCurrentTokenSupply(),  1);
        address ownerOfID1 = bondNFT.ownerOf(1);
        assertEq(ownerOfID1, A);
        
        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check owner of NFT id #2 is B
        address ownerOfID2After = bondNFT.ownerOf(2);
        assertEq(ownerOfID2After, B);
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

    // --- chickenOut tests ---

    function testChickenOutReducesTotalPendingLUSD() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get B's bondID
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // get totalPendingLUSD before
        uint totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

       // check totalPendingLUSD decreases by correct amount
        uint totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore - bondAmount);
    }
    
    function testChickenOutDeletesBondData() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get current time
        uint currentTime = block.timestamp;

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Confirm B has correct bond data
        (uint B_bondedLUSD, uint B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenOutTransfersLUSDToBonder() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Get B lusd balance before
        uint B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertEq(B_LUSDBalanceAfter, B_LUSDBalanceBefore + bondAmount);
    }

    function testChickenOutReducesBondNFTTokenCountByOne() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Since B was the last bonder, his bond ID is also the total current supply
        uint B_bondID = bondNFT.getCurrentTokenSupply();
        uint nftTokenSupplyBefore = bondNFT.getCurrentTokenSupply();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint nftTokenSupplyAfter = bondNFT.getCurrentTokenSupply();

        // Check NFT token supply has decreased by 1
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenOutRemovesOwnerOfBondNFT() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Confirm B owns bond #2
        assertEq(B_bondID, 2);
        address ownerOfBondID2 = bondNFT.ownerOf(B_bondID);
        assertEq(ownerOfBondID2, B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        // Expect ownerOF bond ID #2 call to revert due to non-existent owner
        vm.expectRevert("ERC721: owner query for nonexistent token");
        ownerOfBondID2 = bondNFT.ownerOf(B_bondID);
    }

    function testChickenOutDecreasesBonderNFTBalance() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Confirm B's NFT balance is 1
        uint B_NFTBalanceBefore = bondNFT.balanceOf(B);
        assertEq(B_NFTBalanceBefore, 1);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint B_NFTBalanceAfter = bondNFT.balanceOf(B);

        // Check B's NFT balance has decreased by 1
        assertEq(B_NFTBalanceAfter, B_NFTBalanceBefore - 1);
    }

    //  function testFailOutChickenCallerIsNotBonder() public {
    //     //TODO 
    // }

    // --- calcsLUSD Accrual tests ---

    function testCalcAccruedSLUSDReturns0for0StartTime() public {}

    // Use Foundry fuzz test here!
    function testCalcAccruedSLUSDIsMonotonicIncreasingWithTime(uint _timeSinceBonded) public {}

    function testCalcSLUSDAccrualIncreasesWithTimeForABonder() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        uint A_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSDBefore, 0);

        // Get current time
        uint currentTime = block.timestamp;

        // 10 minutes passes 
        vm.warp(block.timestamp + 600);

        uint A_accruedSLUSDAfter = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertTrue(A_accruedSLUSDAfter > A_accruedSLUSDBefore);
    }

      function testCalcSLUSDAccrualIReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        // Get current time
        uint currentTime = block.timestamp;

        // A chickens out
        chickenBondManager.chickenOut(A_bondID);

        // Check A's accrued SLUSD is 0
        uint A_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSDBefore, 0);
    }

    function testCalcSLUSDAccrualReturns0ForNonBonder() public {
          // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint unusedBondID = bondNFT.getCurrentTokenSupply() + 1;

        // 10 minutes passes 
        vm.warp(block.timestamp + 600);

        // Check accrued sLUSD for a nonexistent bond is 0
        uint accruedSLUSD = chickenBondManager.calcAccruedSLUSD(unusedBondID);
        assertEq(accruedSLUSD, 0);
    }

    // --- chickenIn tests ---

    function testChickenInDeletesBondData() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get current time
        uint currentTime = block.timestamp;

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Confirm B has correct bond data
        (uint B_bondedLUSD, uint B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // 10 minutes passes 
        vm.warp(block.timestamp + 600);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenInTransfersAccruedSLUSDToBonder() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get current time
        uint currentTime = block.timestamp;

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // Get B sLUSD balance before
        uint B_sLUSDBalanceBefore = sLUSDToken.balanceOf(B);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get B's accrued sLUSD and confirm it is non-zero
        uint B_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(B_bondID);
        
        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check B's sLUSD balance has increased by correct amount
        uint B_sLUSDBalanceAfter = sLUSDToken.balanceOf(B);
        assertEq(B_sLUSDBalanceAfter, B_sLUSDBalanceBefore + B_accruedSLUSD);
    }

    // function testFailChickenInCallerIsNotBonder() public {}
    // function testFailChickenInBackingRatioExceedsCap() public {}
    function testChickenInIncreasesTotalAcquiredLUSD() public {}
    function testChickenInReducesBondNFTTokenCountByOne() public {}
    function testChickenInDecreasesBonderNFTBalance() public {}
    function testChickenInRemovesOwnerOfBondNFT() public {}

    // --- redemption tests ---

    // function testFailRedeemWhenCallerHasInsufficientSLUSD() public {}
    // function testFailRedeemWhenPOLisZero() public {}

    function testRedeemDecreasesCallersSLUSDBalance() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        // Get current time
        uint currentTime = block.timestamp;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check B's sLUSD balance has decreased
        uint B_sLUSDBalanceAfter = sLUSDToken.balanceOf(B);
        assertTrue(B_sLUSDBalanceAfter < sLUSDBalance);
        assertTrue(B_sLUSDBalanceAfter > 0);
    }

    function testRedeemDecreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        // Get current time
        uint currentTime = block.timestamp;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();

        // Check total acquired LUSD has decreased and is non-zero
        assertTrue(totalAcquiredLUSDAfter < totalAcquiredLUSDBefore);
        assertTrue(totalAcquiredLUSDAfter > 0);
    }

    function testRedeemDecreasesTotalSLUSDSupply() public {
         // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        // Get current time
        uint currentTime = block.timestamp;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint totalSLUSDBefore = sLUSDToken.totalSupply();

        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint totalSLUSDAfter = sLUSDToken.totalSupply();

         // Check total sLUSD supply has decreased and is non-zero
        assertTrue(totalSLUSDAfter < totalSLUSDBefore);
        assertTrue(totalSLUSDAfter > 0);
    }

    function testRedeemIncreasesCallersLUSDBalance() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        // Get current time
        uint currentTime = block.timestamp;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint B_LUSDBalanceAfter = lusdToken.balanceOf(B);

        // Check B's LUSD Balance has increased
        assertTrue(B_LUSDBalanceAfter > B_LUSDBalanceBefore);
    }
}
