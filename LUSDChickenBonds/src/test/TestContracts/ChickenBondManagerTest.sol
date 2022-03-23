
pragma solidity ^0.8.10;

import "./BaseTest.sol";

contract ChickenBondManagerTest is BaseTest {
    function testSetupSetsBondNFTAddressInCBM() public {
        assertTrue(address(chickenBondManager.bondNFT()) == address(bondNFT));
    }

    function testSetupSetsCMBAddressInBondNFT() public {
        assertTrue(bondNFT.chickenBondManagerAddress() == address(chickenBondManager));
    }

    function testYearnLUSDVaultHasInfiniteLUSDApproval() public {
       uint256 allowance = lusdToken.allowance(address(chickenBondManager), address(yearnLUSDVault));
       assertEq(allowance, 2**256 - 1);
    }

    function testYearnCurveLUSDVaultHasInfiniteLUSDApproval() public {
        // TODO
    }

    // --- createBond tests ---

    function testFirstCreateBondDoesNotChangeBackingRatio() public {
        // Get initial backing ratio
        uint256 backingRatioBefore = chickenBondManager.calcSystemBackingRatio();

        // A approves the system for LUSD transfer and creates the bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);

        // check backing ratio after has not changed
        uint256 backingRatioAfter = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatioAfter, backingRatioBefore);
    }

    function testCreateBondDoesNotChangeBackingRatio() public {
        // A approves the system for LUSD transfer and creates the bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

         // Get initial backing ratio
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();
        
        // B approves the system for LUSD transfer and creates the bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        vm.stopPrank();

        // check backing ratio after has not changed
        uint256 backingRatio_2 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_1, backingRatio_2);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();
    
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // Get backing ratio 3
        uint256 backingRatio_3 = chickenBondManager.calcSystemBackingRatio();
    
        // C creates bond
        vm.startPrank(C);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);

        // Check backing ratio is unchanged by the last bond creation
        uint256 backingRatio_4 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_4, backingRatio_3);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensIn() public {
        // A approves the system for LUSD transfer and creates the bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(20e18);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(20e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // C creates bond
        vm.startPrank(C);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        
        uint256 bondID_C = bondNFT.totalMinted();
        (uint256 bondedLUSD_C, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);

        // assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

      function testCreateBondSucceedsAfterAnotherBonderChickensOut() public {
        // A approves the system for LUSD transfer and creates the bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);
        vm.stopPrank();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A);
        vm.stopPrank();

        uint256 totalPendingLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalPendingLUSD, 0);

        // C creates bond
        vm.startPrank(C);
        lusdToken.approve(address(chickenBondManager), 100e18);
        chickenBondManager.createBond(25e18);

        vm.warp(block.timestamp + 600);

        uint256 bondID_C = bondNFT.totalMinted();
        (uint256 bondedLUSD_C, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);
        assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

    function testFirstCreateBondIncreasesTotalPendingLUSD(uint _bondAmount) public {
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
        uint256 balanceBefore = lusdToken.balanceOf(A);

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check A balance has reduced by correct amount
        uint256 balanceAfter = lusdToken.balanceOf(A);
        assertEq(balanceBefore - 10e18, balanceAfter);
    }

    function testCreateBondRecordsBondData() public {
        // A creates bond #1
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Confirm bond data for bond #2 is 0
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);

        uint256 currentTime = block.timestamp;

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

    function testFirstCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testFirstCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();
        
        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();
        
        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();

        // Check NFT total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesBonderNFTBalanceByOne() public {
        // Check A has no NFTs
        uint256 A_NFTBalanceBefore = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceBefore, 0);

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        chickenBondManager.createBond(10e18);
        vm.stopPrank();
        
        // Check A now has one NFT
        uint256 A_NFTBalanceAfter = bondNFT.balanceOf(A);
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
        assertEq(bondNFT.totalMinted(),  1);
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

    function testCreateBondRevertsWithZeroInputAmount() public {
        // A tries to bond 0 LUSD
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.createBond(0);
    }

    // --- chickenOut tests ---

    function testChickenOutReducesTotalPendingLUSD() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get B's bondID
        uint256 B_bondID = bondNFT.totalMinted();

        // get totalPendingLUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

       // check totalPendingLUSD decreases by correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore - bondAmount);
    }
    
    function testChickenOutDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 currentTime = block.timestamp;

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
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
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B lusd balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertEq(B_LUSDBalanceAfter, B_LUSDBalanceBefore + bondAmount);
    }

    function testChickenOutReducesBondNFTSupplyByOne() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Since B was the last bonder, his bond ID is the current total minted
        uint256 B_bondID = bondNFT.totalMinted();
        uint256 nftTokenSupplyBefore = bondNFT.tokenSupply();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 nftTokenSupplyAfter = bondNFT.tokenSupply();

        // Check NFT token supply has decreased by 1
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenOutDoesNotChangeBondNFTTotalMinted() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Since B was the last bonder, his bond ID is the current total minted
        uint256 B_bondID = bondNFT.totalMinted();
        uint256 nftTotalMintedBefore = bondNFT.totalMinted();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 nftTotalMintedAfter = bondNFT.totalMinted();

        // Check NFT token minted does not change
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenOutRemovesOwnerOfBondNFT() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

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
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B's NFT balance is 1
        uint256 B_NFTBalanceBefore = bondNFT.balanceOf(B);
        assertEq(B_NFTBalanceBefore, 1);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 B_NFTBalanceAfter = bondNFT.balanceOf(B);

        // Check B's NFT balance has decreased by 1
        assertEq(B_NFTBalanceAfter, B_NFTBalanceBefore - 1);
    }

    function testChickenOutRevertsWhenCallerIsNotBonder() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 A_bondID = bondNFT.totalMinted();

        // B tries to chicken out A's bond
        vm.startPrank(B);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(A_bondID);

        // B tries to chicken out non-existent bond
        vm.expectRevert("ERC721: owner query for nonexistent token");
        chickenBondManager.chickenOut(37);
    }

    function testChickenOutRevertsWhenBonderChickensOutBondTheyDontOwn() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

        // A attempts to chicken out B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(B_bondID);
    }

    // --- calcsLUSD Accrual tests ---

    function testCalcAccruedSLUSDReturns0for0StartTime() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 A_bondID = bondNFT.totalMinted();

        uint256 A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSD, 0);
    }

    function testCalcAccruedSLUSDReturnsNonZeroSLUSDForNonZeroInterval(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        uint256 A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertTrue(A_accruedSLUSD > 0);

        // --- Test subsequent bond ---

        vm.warp(block.timestamp + 30 days);

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Time interval passes
        vm.warp(block.timestamp + _interval);
        
        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
    }

    // TODO: convert to fuzz test
    function testCalcAccruedSLUSDNeverReachesCap(uint _interval) public {
         // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(A_bondID) < chickenBondManager.calcBondSLUSDCap(A_bondID));

        // --- Test subsequent bond ---
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);
        
        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
    }

    function testCalcAccruedSLUSDIsMonotonicIncreasingWithTime(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume( _interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        uint accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(bondID_A);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(bondID_A);
        assertTrue(newAccruedSLUSD_A > accruedSLUSD_A);
        
        // time passes
        vm.warp(block.timestamp + 30 days);

        // --- Test subsequent bond ---

        // A chickens in
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        //B creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 bondID_B = bondNFT.totalMinted();

        uint accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(bondID_B);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(bondID_B);
        assertTrue(newAccruedSLUSD_B > accruedSLUSD_B);
    }

    function testCalcSLUSDAccrualIReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();
       
        // A chickens out
        chickenBondManager.chickenOut(A_bondID);

        // Check A's accrued SLUSD is 0
        uint256 A_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSDBefore, 0);
    }

    function testCalcSLUSDAccrualReturns0ForNonBonder() public {
          // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 unusedBondID = bondNFT.totalMinted() + 1;

        // 10 minutes passes 
        vm.warp(block.timestamp + 600);

        // Check accrued sLUSD for a nonexistent bond is 0
        uint256 accruedSLUSD = chickenBondManager.calcAccruedSLUSD(unusedBondID);
        assertEq(accruedSLUSD, 0);
    }

    // --- calcSystemBackingRatio tests ---

    function testBackingRatioIsOneBeforeFirstChickenIn() public {
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_1, 1e18);

        uint256 bondAmount = 10e18;

        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 backingRatio_2 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_2, 1e18);

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 backingRatio_3 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_3, 1e18);
    }
   
    // --- chickenIn tests ---

    function testChickenInSucceedsAfterShortBondingInterval(uint256 _interval) public {
        vm.assume(_interval > 1  && _interval < 1 weeks); // Interval in range [10 seconds, 1 week]

        // uint _interval = 10;

        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        vm.warp(block.timestamp + _interval);
      
        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);
    }

    function testChickenInDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        tip(address(sLUSDToken), B, 5e18);

        uint256 currentTime = block.timestamp;

       // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
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
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // Get B sLUSD balance before
        uint256 B_sLUSDBalanceBefore = sLUSDToken.balanceOf(B);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get B's accrued sLUSD and confirm it is non-zero
        uint256 B_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(B_bondID);
        
        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check B's sLUSD balance has increased by correct amount
        uint256 B_sLUSDBalanceAfter = sLUSDToken.balanceOf(B);
        assertEq(B_sLUSDBalanceAfter, B_sLUSDBalanceBefore + B_accruedSLUSD);
    }

     function testChickenInIncreasesBondHolderLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get B LUSD balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);
    
        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check B's LUSD balance has increased by correct amount
        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertGt(B_LUSDBalanceAfter, B_LUSDBalanceBefore);
    }
    
    
    function testChickenInDecreasesTotalPendingLUSDByBondAmount() public {
         // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get total pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check total pending LUSD has increased by correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertLt(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    function testChickenInIncreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get total pending LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        // Check total acquired LUSD has increased by correct amount
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }

    function testChickenInReducesBondNFTSupplyByOne() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        uint256 nftTokenSupplyBefore = bondNFT.tokenSupply();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenInDoesNotChangeTotalMinted() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        uint256 nftTotalMintedBefore = bondNFT.totalMinted();

        // B chickens in
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTotalMintedAfter = bondNFT.totalMinted();
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenInDecreasesBonderNFTBalanceByOne() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();
        
        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        uint256 nftTokenSupplyBefore = bondNFT.totalMinted();

        // Get B's NFT balance before
        uint256 B_bondNFTBalanceBefore = bondNFT.balanceOf(B);
 
        // B chickens in
        chickenBondManager.chickenIn(B_bondID);
        
        // Check B's NFT balance decreases by 1
        uint256 B_bondNFTBalanceAfter = bondNFT.balanceOf(B);
        assertEq(B_bondNFTBalanceAfter, B_bondNFTBalanceBefore - 1);
    }

    function testChickenInRemovesOwnerOfBondNFT() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

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
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 A_bondID = bondNFT.totalMinted();
        uint256 nonexistentBondID = bondNFT.totalMinted() + 1;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm B has no bonds
        uint256 B_bondCount = bondNFT.balanceOf(B);
        assertEq(B_bondCount, 0);
        
        // B tries to chicken out A's bond
        vm.startPrank(B);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenIn(A_bondID);

        // B tries to chicken out a non-existent bond
        vm.expectRevert("ERC721: owner query for nonexistent token");
        chickenBondManager.chickenIn(37);   
   }

    function testChickenInRevertsWhenBonderChickensInBondTheyDontOwn() public { 
         // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm bond owner is B
        address bondOwnerBefore = bondNFT.ownerOf(B_bondID);
        assertEq(bondOwnerBefore, B);

        // A tries to chickens in B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenIn(B_bondID);
    }

    // --- redemption tests ---

    function testRedeemDecreasesCallersSLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check B's sLUSD balance has decreased
        uint256 B_sLUSDBalanceAfter = sLUSDToken.balanceOf(B);
        assertTrue(B_sLUSDBalanceAfter < sLUSDBalance);
        assertTrue(B_sLUSDBalanceAfter > 0);
    }

    function testRedeemDecreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();

        // Check total acquired LUSD has decreased and is non-zero
        assertTrue(totalAcquiredLUSDAfter < totalAcquiredLUSDBefore);
        assertTrue(totalAcquiredLUSDAfter > 0);
    }

    function testRedeemDecreasesTotalSLUSDSupply() public {
         // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
    
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint256 totalSLUSDBefore = sLUSDToken.totalSupply();

        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint256 totalSLUSDAfter = sLUSDToken.totalSupply();

         // Check total sLUSD supply has decreased and is non-zero
        assertTrue(totalSLUSDAfter < totalSLUSDBefore);
        assertTrue(totalSLUSDAfter > 0);
    }

    function testRedeemIncreasesCallersLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);

        // Check B's LUSD Balance has increased
        assertTrue(B_LUSDBalanceAfter > B_LUSDBalanceBefore);
    }

    function testRedeemDecreasesAcquiredLUSDInYearnByCorrectFraction() public {
        uint256 redemptionFraction = 5e17; // 50%
        uint256 percentageFee = chickenBondManager.calcRedemptionFeePercentage();
        uint256 fractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;

        // A creates bond
        uint256 bondAmount = 10e18;
       
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));
        vm.stopPrank();

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();
        
        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check acquired LUSD in Yearn has decreased by correct fraction
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        uint256 expectedAcquiredLUSDInYearnAfter = acquiredLUSDInYearnBefore * fractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLUSDInYearnAfter, expectedAcquiredLUSDInYearnAfter, 1000);
    }

    function testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction() public {
        uint256 redemptionFraction = 5e17; // 50%
        uint256 percentageFee = chickenBondManager.calcRedemptionFeePercentage();
        uint256 fractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;

        // A creates bond
        uint256 bondAmount = 10e18;
       
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));

        // A shifts some LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Get acquired LUSD in Curve before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(acquiredLUSDInCurveBefore > 0);

        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check acquired LUSD in curve after has reduced by correct fraction
        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 expectedAcquiredLUSDInCurveAfter = acquiredLUSDInCurveBefore * fractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLUSDInCurveAfter, expectedAcquiredLUSDInCurveAfter, 1000);
    }

    function testRedeemRevertsWhenCallerHasInsufficientSLUSD() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // A transfers some sLUSD to B
        vm.startPrank(A);
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        vm.stopPrank();

        uint B_sLUSDBalance = sLUSDToken.balanceOf(B);
        assertGt(B_sLUSDBalance, 0);

        // B tries to redeem more LUSD than they have
        vm.startPrank(B);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        chickenBondManager.redeem(B_sLUSDBalance + 1);

        /* Reverts on transfer rather than burn, since it tries to redeem more than the total SLUSD supply, and therefore tries 
        * to withdraw more LUSD than is held by the system */
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        chickenBondManager.redeem(B_sLUSDBalance + 13e37);
    }

    function testRedeemRevertsWithZeroInputAmount() public {
         // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Check B's sLUSD balance is zero
        uint256 B_sLUSDBalance = sLUSDToken.balanceOf(B);
        assertEq(B_sLUSDBalance, 0);

        // B tries to redeem with 0 sLUSD balance
        vm.startPrank(B);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.redeem(0);
    }

    function testFailRedeemRevertsWhenTotalAcquiredLUSDisZero() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // confirm acquired LUSD is 0
        assertEq(chickenBondManager.getTotalAcquiredLUSD(), 0);

        // Cheat: tip 5e18 sLUSD to B
        tip(address(sLUSDToken), B, 5e18);
        uint256 B_sLUSDBalance = sLUSDToken.balanceOf(B);
        assertEq(B_sLUSDBalance, 5e18);

        // B tries to redeem his sLUSD while there is 0 total acquired LUSD
        vm.startPrank(B);
        chickenBondManager.redeem(5e18);
    }

    // --- shiftLUSDFromSPToCurve tests -

    // CBM system trackers
    function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();
        
        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertEq(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }
    
    function testShiftLUSDFromSPToCurveDoesntChangeCBMPendingLUSDTracker() public {
        uint256 bondAmount = 25e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check pending LUSD After has not changed 
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers 
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check acquired LUSD in Yearn has decreased
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter < acquiredLUSDInYearnBefore);
    } 
    
    function testShiftLUSDFromSPToCurveDecreasesCBMLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Yearn  
        uint256 lusdInYearnBefore = chickenBondManager.calcYearnLUSDVaultShareValue();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check CBM's view of LUSD in Yearn has decreased
        uint256 lusdInYearnAfter = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter < lusdInYearnBefore);
    }

    function testShiftLUSDFromSPToCurveIncreasesCBMLUSDInCurveTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Curve before
        uint256 lusdInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from SP to Curve
        chickenBondManager.shiftLUSDFromSPToCurve();

        // Check CBM's view of LUSD in Curve has inccreased
        uint256 lusdInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(lusdInCurveAfter > lusdInCurveBefore);
    }

    // Actual Yearn and Curve balance tests
    // function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInYearnAndCurve() public {}

    // function testShiftLUSDFromSPToCurveDecreasesLUSDInYearn() public {}
    // function testShiftLUSDFromSPToCurveIncreaseLUSDInCurve() public {}

    // function testFailShiftLUSDFromSPToCurveWhen0LUSDInYearn() public {}
    // function testShiftLUSDFromSPToCurveRevertsWithZeroLUSDinSP() public {}
   

    // --- shiftLUSDFromCurveToSP tests ---

    function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);
    
        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();
        
        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertEq(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMPendingLUSDTracker() public {// A creates bond
        uint256 bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check pending LUSD After has not changed 
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers
    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInYearnTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get acquired LUSD in Yearn Before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check acquired LUSD in Yearn Increases
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter > acquiredLUSDInYearnBefore);
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInYearnTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get LUSD in Yearn Before
        uint256 lusdInYearnBefore = chickenBondManager.calcYearnLUSDVaultShareValue();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check LUSD in Yearn Increases
        uint256 lusdInYearnAfter = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter > lusdInYearnBefore);
    }
    
    
    function testShiftLUSDFromCurveToSPDecreasesCBMLUSDInCurveTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        chickenBondManager.shiftLUSDFromSPToCurve();
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Get acquired LUSD in Curve Before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from Curve to SP
        chickenBondManager.shiftLUSDFromCurveToSP();

        // Check LUSD in Curve Decreases
        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        assertTrue(acquiredLUSDInCurveAfter < acquiredLUSDInCurveBefore);
    }


    // Actual Yearn and Curve balance tests

    // function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInYearnAndCurve() public {}

    // function testShiftLUSDFromCurveToSPIncreasesLUSDInYearn() public {}
    // function testShiftLUSDFromCurveToSPDecreasesLUSDInCurve() public {}

    // function testFailShiftLUSDFromCurveToSPWhen0LUSDInCurve() public {}

    // --- Yearn Registry tests ---

    function testCorrectLatestYearnLUSDVault() public {
        assertEq(yearnRegistry.latestVault(address(lusdToken)), address(yearnLUSDVault));
    }

    function testCorrectLatestYearnCurveVault() public {
        assertEq(yearnRegistry.latestVault(address(curvePool)), address(yearnCurveVault));
    }

    // --- calcYearnLUSDVaultShareValue tests ---

    // Test whether the CBM share value calculator correctly calculates what actually will be withdrawn from Yearn.
    // function testCalcYearnLUSDShareValueGivesCorrectAmountAtFirstDepositPartialWithdrawal() public {
    //     uint256 depositAmount = 10e18;
    //     // Tip CBM some LUSD 
    //     tip(address(lusdToken), address(chickenBondManager), depositAmount);

    //     // Artificially deposit LUSD to Yearn, as CBM
    //     vm.startPrank(address(chickenBondManager));
    //     yearnLUSDVault.deposit(depositAmount);
    //     assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

    //     // Calc share value
    //     uint256 CBMShareLUSDValue = chickenBondManager.calcYearnLUSDVaultShareValue();
    //     assertGt(CBMShareLUSDValue, 0);

    //     // Artificually withdraw half the shares
    //     uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
    //     yearnLUSDVault.withdraw(shares / 2);

    //     // Check that the CBM received half of its share value
    //     assertEq(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue / 2);
    // }

    function testCalcYearnLUSDShareValueGivesCorrectAmountAtFirstDepositFullWithdrawal() public {
        uint256 depositAmount = 10e18;

        // Tip CBM some LUSD 
        tip(address(lusdToken), address(chickenBondManager), depositAmount);

        // Artificially deposit LUSD to Yearn, as CBM
        vm.startPrank(address(chickenBondManager));
        yearnLUSDVault.deposit(depositAmount);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLUSDValue = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(CBMShareLUSDValue, 0);

        // Artifiiually withdraw all the share value as CBM  
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares);

        // Check that the CBM received all of it's share value
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue);
    }

    function testCalcYearnLUSDShareValueGivesCorrectAmountAtFirstDepositPartialWithdrawal(uint _denominator) public {
       // Assume we withdraw something between full amount and 1 billion'th.  At some point, the denominator would become
       // too large, the share amount too small to withdraw any LUSD, and the withdrawal will revert.
        vm.assume(_denominator > 0 && _denominator < 1e9);

        uint256 depositAmount = 10e18;
        // Tip CBM some LUSD 
        tip(address(lusdToken), address(chickenBondManager), depositAmount);

        // Artificially deposit LUSD to Yearn, as CBM
        vm.startPrank(address(chickenBondManager));
        yearnLUSDVault.deposit(depositAmount);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLUSDValue = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(CBMShareLUSDValue, 0);

        // Artificially withdraw fraction of the shares
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares / _denominator);

        // Check that the CBM received correct fraction of the shares
        uint lusdBalAfter = lusdToken.balanceOf(address(chickenBondManager));
        uint fractionalCBMShareValue = CBMShareLUSDValue / _denominator;
        console.log(lusdBalAfter, "lusdBalAfter");
        console.log(fractionalCBMShareValue, "fractionalCBMShareValue");

        assertApproximatelyEqual(lusdBalAfter, fractionalCBMShareValue, 1e3);
    }

    function testCalcYearnLUSDShareValueGivesCorrectAmountAtFirstDepositFullWithdrawal(uint _depositAmount) public {
        // Assume  10 wei < deposit < availableDepositLimit  (For very tiny deposits <10wei, the Yearn vault share calculation can  round to 0).
        uint256 availableDepositLimit = yearnLUSDVault.availableDepositLimit();
        vm.assume(_depositAmount < availableDepositLimit && _depositAmount > 10);

        // Tip CBM some LUSD 
        tip(address(lusdToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to Yearn, as CBM
        vm.startPrank(address(chickenBondManager));
        yearnLUSDVault.deposit(_depositAmount);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLUSDValue = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(CBMShareLUSDValue, 0);

        // Artifiiually withdraw all the share value as CBM  
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares);

        // Check that the CBM received all of it's share value
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue);
    }

       function testCalcYearnLUSDShareValueGivesCorrectAmountAtSubsequentDepositFullWithdrawal(uint _depositAmount) public {
        // Assume  10 wei < deposit < availableDepositLimit  (For very tiny deposits <10wei, the Yearn vault share calculation can  round to 0).
        uint256 availableDepositLimit = yearnLUSDVault.availableDepositLimit();
        vm.assume(_depositAmount < availableDepositLimit && _depositAmount > 10);

        // Tip CBM some LUSD 
        tip(address(lusdToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to Yearn, as CBM
        vm.startPrank(address(chickenBondManager));
        yearnLUSDVault.deposit(_depositAmount);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLUSDValue = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(CBMShareLUSDValue, 0);

        // Artifiiually withdraw all the share value as CBM  
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares);

        // Check that the CBM received all of it's share value
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue);
    }

    // Test calculated share value does not change over time, ceteris paribus
    function testCalcYearnLUSDShareValueDoesNotChangeOverTimeAllElseEqual() public { 
        uint256 bondAmount = 10e18;
        
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

        // Get share value 1
        uint256 lusdVaultshareValue_1 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(lusdVaultshareValue_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 2 == share value 1
        uint256 lusdVaultshareValue_2 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertEq(lusdVaultshareValue_2, lusdVaultshareValue_1);

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get share value 3
        uint256 lusdVaultshareValue_3 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(lusdVaultshareValue_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 4 == share value 3
        uint256 lusdVaultshareValue_4 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertEq(lusdVaultshareValue_4, lusdVaultshareValue_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);

        
        // Get share value 5
        uint256 lusdVaultshareValue_5 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(lusdVaultshareValue_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 5 == share value 6
         uint256 lusdVaultshareValue_6 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertEq(lusdVaultshareValue_6, lusdVaultshareValue_5);
    }
    
    // Test totalShares does not change over time ceteris paribus
    function testYearnTotalLUSDYTokensDoesNotChangeOverTimeAllElseEqual() public { 
        uint256 bondAmount = 10e18;
        
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

        // Get total yTokens 1
        uint256 yTokensYearnLUSD_1 = yearnLUSDVault.totalSupply();
        assertGt(yTokensYearnLUSD_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total YTokens 2 ==   total yTokens 1
        uint256 yTokensYearnLUSD_2 = yearnLUSDVault.totalSupply();
        assertEq(yTokensYearnLUSD_2, yTokensYearnLUSD_1);

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get total yTokens  3
        uint256 yTokensYearnLUSD_3 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(yTokensYearnLUSD_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total yTokens 4 == total yTokens 3
        uint256 yTokensYearnLUSD_4 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertEq(yTokensYearnLUSD_4, yTokensYearnLUSD_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        
        // Get total yTokens 5
        uint256 yTokensYearnLUSD_5 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertGt(yTokensYearnLUSD_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total yTokens 5 == total yTokens 6
         uint256 yTokensYearnLUSD_6 = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertEq(yTokensYearnLUSD_6, yTokensYearnLUSD_5);
    }

    // Test CBM shares does not change over time ceteris paribus
    function testCBMYearnLUSDYTokensDoesNotChangeOverTimeAllElseEqual() public { 
        uint256 bondAmount = 10e18;
        
        // A creates bond
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        uint256 bondID_A = bondNFT.totalMinted();

        // Get CBM yTokens 1
        uint256 CBMyTokensYearnLUSD_1 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertGt(CBMyTokensYearnLUSD_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM YTokens 2 ==  CBM yTokens 1
        uint256 CBMyTokensYearnLUSD_2 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertEq(CBMyTokensYearnLUSD_2, CBMyTokensYearnLUSD_1);

        // B creates bond
        vm.startPrank(B);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        chickenBondManager.createBond(bondAmount);
        vm.stopPrank();

        // Get CBM yTokens 3
        uint256 CBMyTokensYearnLUSD_3 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertGt(CBMyTokensYearnLUSD_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM yTokens 4 == CBM yTokens 3
        uint256 CBMyTokensYearnLUSD_4 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertEq(CBMyTokensYearnLUSD_4, CBMyTokensYearnLUSD_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        
        // Get CBM yTokens 5
        uint256 CBMyTokensYearnLUSD_5 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertGt(CBMyTokensYearnLUSD_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM yTokens 5 == CBM yTokens 6
         uint256 CBMyTokensYearnLUSD_6 = yearnLUSDVault.balanceOf(address(chickenBondManager));
        assertEq(CBMyTokensYearnLUSD_6, CBMyTokensYearnLUSD_5);
    }

    function testYearnLUSDVaultImmediateDepositAndWithdrawalReturnsAlmostExactDeposit(uint _depositAmount) public {
        // Assume  10 wei < deposit < availableDepositLimit  (For very tiny deposits <10wei, the Yearn vault share calculation can  round to 0).
        uint256 availableDepositLimit = yearnLUSDVault.availableDepositLimit();
        vm.assume(_depositAmount < availableDepositLimit && _depositAmount > 10);

        // Tip CBM some LUSD 
        tip(address(lusdToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to Yearn, as CBM
        vm.startPrank(address(chickenBondManager));
        yearnLUSDVault.deposit(_depositAmount); 
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Artifiiually withdraw all the share value as CBM  
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares);

        // Check that CBM was able to withdraw almost exactly its initial deposit
        assertApproximatelyEqual(_depositAmount, lusdToken.balanceOf(address(chickenBondManager)), 1e3);
    }
}