// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "../ChickenBondManager.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
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
    function assume(bool) external;
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

    function assertEqWithErrorMargin(uint256 _x, uint256 _y, uint256 _margin) public {
        uint256 diff = abs(_x, _y);
        assertLe(diff, _margin);
    }

    function abs(uint256 x, uint256 y) public returns (uint256) {
        return x > y ? x - y : y - x;
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

    function testFirstCreateBondIncreasesTheBondNFTCountByOne() public {
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

    function testCreateBondIncreasesTheBondNFTCountByOne() public {
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

    function testCreateBondIncreasesBonderNFTBalanceByOne() public {
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

    function testChickenOutReducesBondNFTCountByOne() public {
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

    function testChickenOutDecreasesBonderNFTBalanceByOne() public {
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

    function testCalcAccruedSLUSDReturns0for0StartTime() public {
        // A, B create bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        uint A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSD, 0);
    }

     // TODO: convert to fuzz test
    function testCalcAccruedSLUSDReturnsNonZeroSLUSDForNonZeroInterval() public {
        uint _1Month = 60 * 60 * 24 * 30;

        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        vm.warp(block.timestamp + _1Month);

        uint A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertTrue(A_accruedSLUSD > 0);
    }

    // TODO: convert to fuzz test
    function testCalcAccruedSLUSDNeverReachesCap() public {
        uint tenMinutes = 60 * 60 * 10;
        uint thousandYears = 60 * 60 * 24 * 365 * 1000;

        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        // time passes
        vm.warp(block.timestamp + tenMinutes);

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + tenMinutes);
        
        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
        
        // 1000 years passes
        vm.warp(block.timestamp + thousandYears);

        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
    }

    // TODO: convert to fuzz test
    function testCalcAccruedSLUSDIsMonotonicIncreasingWithTime(uint _timeSinceBonded) public {
        uint tenMinutes = 60 * 60 * 10;
        uint thousandYears = 60 * 60 * 24 * 365 * 1000;

        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        // time passes
        vm.warp(block.timestamp + tenMinutes);

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint B_bondID = bondNFT.getCurrentTokenSupply();
    
        uint time = block.timestamp;
        uint accruedSLUSD;
        for (uint256 i = 0; i < 5; i++) {
            // 10 minutes passes
            time += tenMinutes;
            vm.warp(time);
            uint newAccruedSLUSD = chickenBondManager.calcBondSLUSDCap(B_bondID);
            assertTrue(newAccruedSLUSD > accruedSLUSD);
        }
    }

    // TODO: convert to fuzz test
    function testCalcSLUSDAccrualIncreasesWithTimeForABonder() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint A_bondID = bondNFT.getCurrentTokenSupply();

        uint A_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSDBefore, 0);

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

     function testChickenInIncreasesBondHolderLUSDBalance() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get B LUSD balance before
        uint B_LUSDBalanceBefore = lusdToken.balanceOf(B);
    
        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check B's LUSD balance has increased by correct amount
        uint B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertGt(B_LUSDBalanceAfter, B_LUSDBalanceBefore);
    }
    
    
    function testChickenInDecreasesTotalPendingLUSDByBondAmount() public {
         // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get total pending LUSD before
        uint totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check total pending LUSD has increased by correct amount
        uint totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertLt(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    function testChickenInIncreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get total pending LUSD before
        uint totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check total acquired LUSD has increased by correct amount
        uint totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }

    function testChickenInReducesBondNFTCountByOne() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        uint nftTokenSupplyBefore = bondNFT.getCurrentTokenSupply();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        uint nftTokenSupplyAfter = bondNFT.getCurrentTokenSupply();
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenInDecreasesBonderNFTBalanceByOne() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        uint nftTokenSupplyBefore = bondNFT.getCurrentTokenSupply();

        // Get B's NFT balance before
        uint B_bondNFTBalanceBefore = bondNFT.balanceOf(B);

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check B's NFT balance decreases by 1
        uint B_bondNFTBalanceAfter = bondNFT.balanceOf(B);
        assertEq(B_bondNFTBalanceAfter, B_bondNFTBalanceBefore - 1);
    }

    function testChickenInRemovesOwnerOfBondNFT() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint B_bondID = bondNFT.getCurrentTokenSupply();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm bond owner is B
        address bondOwnerBefore = bondNFT.ownerOf(B_bondID);
        assertEq(bondOwnerBefore, B);

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Expert revert when we check for the owner of a non-existent token
        vm.expectRevert("ERC721: owner query for nonexistent token");
        address bondOwnerAfter = bondNFT.ownerOf(B_bondID);
    }

    function testChickenInRevertsWhenCallerIsNotABonder() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint A_bondID = bondNFT.getCurrentTokenSupply();
        uint nonexistentBondID = bondNFT.getCurrentTokenSupply() + 1;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm B has no bonds
        uint B_bondCount = bondNFT.balanceOf(B);
        
        // Expert revert when non-bonder B 
        vm.startPrank(B);
        vm.expectRevert("ERC721: owner query for nonexistent token");
        chickenBondManager.chickenIn(bondAmount);
    }
    
    // --- redemption tests ---

    // function testFailRedeemWhenCallerHasInsufficientSLUSD() public {}
    // function testFailRedeemWhenPOLisZero() public {}

    function testRedeemDecreasesCallersSLUSDBalance() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

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

    function testRedeemDecreasesAcquiredLUSDInYearnByCorrectFraction() public {
        uint redemptionFraction = 5e17; // 50%
        uint percentageFee = chickenBondManager.calcRedemptionFeePercentage();
        uint fractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;

        // A creates bond
        uint bondAmount = 10e18;
       
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

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
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));
        vm.stopPrank();

        // Get acquired LUSD in Yearn before
        uint acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();
        
        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check acquired LUSD in Yearn has decreased by correct fraction
        uint acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        uint expectedAcquiredLUSDInYearnAfter = acquiredLUSDInYearnBefore * fractionRemainingAfterRedemption / 1e18;

        assertEqWithErrorMargin(acquiredLUSDInYearnAfter, expectedAcquiredLUSDInYearnAfter, 1000);
    }

    function testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction() public {
        uint redemptionFraction = 5e17; // 50%
        uint percentageFee = chickenBondManager.calcRedemptionFeePercentage();
        uint fractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;

        // A creates bond
        uint bondAmount = 10e18;
       
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

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
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));

        // A shifts some LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Get acquired LUSD in Curve before
        uint acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(acquiredLUSDInCurveBefore > 0);

        // B redeems some sLUSD
        uint sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check acquired LUSD in curve after has reduced by correct fraction
        uint acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        uint expectedAcquiredLUSDInCurveAfter = acquiredLUSDInCurveBefore * fractionRemainingAfterRedemption / 1e18;

        assertEqWithErrorMargin(acquiredLUSDInCurveAfter, expectedAcquiredLUSDInCurveAfter, 1000);
    }

  


    // --- shiftLUSDFromSPToCurve tests -

    // CBM system trackers
    function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Get total LUSD in CBM before
        uint CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();
        
        // Check total LUSD in CBM has not changed
        uint CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // get CBM's recorded total acquired LUSD before
        uint totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // check CBM's recorded total acquire LUSD hasn't changed
        uint totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertEq(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }
    
    function testShiftLUSDFromSPToCurveDoesntChangeCBMPendingLUSDTracker() public {
        uint bondAmount = 25e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get pending LUSD before
        uint totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check pending LUSD After has not changed 
        uint totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers 
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInYearnTracker() public {
        // A creates bond
        uint bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get acquired LUSD in Yearn before
        uint acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check acquired LUSD in Yearn has decreased
        uint acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter < acquiredLUSDInYearnBefore);
    } 
    
    function testShiftLUSDFromSPToCurveDecreasesCBMLUSDInYearnTracker() public {
        // A creates bond
        uint bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Yearn  
        uint lusdInYearnBefore = chickenBondManager.getLUSDInYearn();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check CBM's view of LUSD in Yearn has decreased
        uint lusdInYearnAfter = chickenBondManager.getLUSDInYearn();
        assertTrue(lusdInYearnAfter < lusdInYearnBefore);
    }

    function testShiftLUSDFromSPToCurveIncreasesCBMLUSDInCurveTracker() public {
        // A creates bond
        uint bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Curve before
        uint lusdInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check CBM's view of LUSD in Curve has inccreased
        uint lusdInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(lusdInCurveAfter > lusdInCurveBefore);
    }

    // Actual Yearn and Curve balance tests
    // function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInYearnAndCurve() public {}

    // function testShiftLUSDFromSPToCurveDecreasesLUSDInYearn() public {}
    // function testShiftLUSDFromSPToCurveIncreaseLUSDInCurve() public {}

    // function testFailShiftLUSDFromSPToCurveWhen0LUSDInYearn() public {}
   

    // --- shiftLUSDFromCurveToSP tests ---

    function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);
    
        // Get total LUSD in CBM before
        uint CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();
        
        // Check total LUSD in CBM has not changed
        uint CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // get CBM's recorded total acquired LUSD before
        uint totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // check CBM's recorded total acquire LUSD hasn't changed
        uint totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertEq(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMPendingLUSDTracker() public {// A creates bond
        uint bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get pending LUSD before
        uint totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check pending LUSD After has not changed 
        uint totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers
    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInYearnTracker() public {
        uint bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get acquired LUSD in Yearn Before
        uint acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check acquired LUSD in Yearn Increases
        uint acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter > acquiredLUSDInYearnBefore);
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInYearnTracker() public {
        uint bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get LUSD in Yearn Before
        uint lusdInYearnBefore = chickenBondManager.getLUSDInYearn();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check LUSD in Yearn Increases
        uint lusdInYearnAfter = chickenBondManager.getLUSDInYearn();
        assertTrue(lusdInYearnAfter > lusdInYearnBefore);
    }
    
    
    function testShiftLUSDFromCurveToSPDecreasesCBMLUSDInCurveTracker() public {
        uint bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint A_bondID = bondNFT.getCurrentTokenSupply();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get acquired LUSD in Curve Before
        uint acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check LUSD in Curve Decreases
        uint acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(acquiredLUSDInCurveAfter < acquiredLUSDInCurveBefore);
    }


    // Actual Yearn and Curve balance tests

    // function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInYearnAndCurve() public {}

    // function testShiftLUSDFromCurveToSPIncreasesLUSDInYearn() public {}
    // function testShiftLUSDFromCurveToSPDecreasesLUSDInCurve() public {}

    // function testFailShiftLUSDFromCurveToSPWhen0LUSDInCurve() public {}
}
