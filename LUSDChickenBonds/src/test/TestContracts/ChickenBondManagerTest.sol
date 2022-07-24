
pragma solidity ^0.8.10;

import "./BaseTest.sol";
import "./QuickSort.sol" as QuickSort;

contract ChickenBondManagerTest is BaseTest {
    function testSetupSetsBondNFTAddressInCBM() public {
        assertTrue(address(chickenBondManager.bondNFT()) == address(bondNFT));
    }

    function testSetupSetsCMBAddressInBondNFT() public {
        assertTrue(bondNFT.chickenBondManagerAddress() == address(chickenBondManager));
    }

    function testYearnLUSDVaultHasInfiniteLUSDApproval() public {
       uint256 allowance = lusdToken.allowance(address(chickenBondManager), address(bammSPVault));
       assertEq(allowance, 2**256 - 1);
    }

    function testYearnCurveLUSDVaultHasInfiniteLUSDApproval() public {
        // TODO
    }

    // --- createBond tests ---

    function testNFTEnumerationWorks() public {
        uint256 A_bondId_1 = createBondForUser(A, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(A, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 1);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 0), 3);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 1), 4);

        // A chickens out the first bond, so it’s removed
        vm.startPrank(A);
        chickenBondManager.chickenOut(A_bondId_1, 0);
        vm.stopPrank();

        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(A, MIN_BOND_AMOUNT + 1e18);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 6);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 0), 3);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 1), 4);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 2), 5);
    }

    function testFirstCreateBondDoesNotChangeBackingRatio() public {
        // Get initial backing ratio
        uint256 backingRatioBefore = chickenBondManager.calcSystemBackingRatio();

        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        // check backing ratio after has not changed
        uint256 backingRatioAfter = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatioAfter, backingRatioBefore);
    }

    function testCreateBondDoesNotChangeBackingRatio() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get initial backing ratio
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();

        // B approves the system for LUSD transfer and creates the bond
        createBondForUser(B, MIN_BOND_AMOUNT + 25e18);

        // check backing ratio after has not changed
        uint256 backingRatio_2 = chickenBondManager.calcSystemBackingRatio();
        assertApproximatelyEqual(backingRatio_2, backingRatio_1, 1e3);

        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // Get backing ratio 3
        uint256 backingRatio_3 = chickenBondManager.calcSystemBackingRatio();

        // C creates bond
        createBondForUser(C, MIN_BOND_AMOUNT + 25e18);

        // Check backing ratio is unchanged by the last bond creation
        uint256 backingRatio_4 = chickenBondManager.calcSystemBackingRatio();
        assertApproximatelyEqual(backingRatio_4, backingRatio_3, 1e3);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensIn() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 20e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
        createBondForUser(B, MIN_BOND_AMOUNT + 20e18);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // C creates bond
        createBondForUser(C, MIN_BOND_AMOUNT + 25e18);

        uint256 bondID_C = bondNFT.totalMinted();
        (, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);

        // assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensOut() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
        createBondForUser(B, MIN_BOND_AMOUNT + 25e18);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A, 0);
        vm.stopPrank();

        uint256 totalPendingLUSD = chickenBondManager.getPendingLUSD();
        assertGt(totalPendingLUSD, 0);

        // C creates bond
        createBondForUser(C, MIN_BOND_AMOUNT + 25e18);

        vm.warp(block.timestamp + 600);

        uint256 bondID_C = bondNFT.totalMinted();
        (uint256 bondedLUSD_C, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);
        assertEq(bondedLUSD_C, MIN_BOND_AMOUNT + 25e18);
        assertEq(bondStartTime_C, block.timestamp - 600);
    }

    function testFirstCreateBondIncreasesTotalPendingLUSD() public {
        // Get initial pending LUSD
        uint256 totalPendingLUSDBefore = chickenBondManager.getPendingLUSD();

        // Confirm initial total pending LUSD is 0
        assertTrue(totalPendingLUSDBefore == 0);

        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertTrue(totalPendingLUSDAfter == MIN_BOND_AMOUNT + 25e18);
    }

    function testCreateBondIncreasesTotalPendingLUSD() public {
        // First, A creates an initial bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        // B creates the bond
        createBondForUser(B, MIN_BOND_AMOUNT + 10e18);

        vm.stopPrank();

        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertTrue(totalPendingLUSDAfter == 2 * MIN_BOND_AMOUNT + 35e18);
    }

    function testCreateBondReducebLUSDBalanceOfBonder() public {
        // Get A balance before
        uint256 balanceBefore = lusdToken.balanceOf(A);

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check A balance has reduced by correct amount
        uint256 balanceAfter = lusdToken.balanceOf(A);
        assertEq(balanceBefore - MIN_BOND_AMOUNT, balanceAfter);
    }

    function testCreateBondRecordsBondData() public {
        // A creates bond #1
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Confirm bond data for bond #2 is 0
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, MIN_BOND_AMOUNT);

        // Check bonded amount and bond start time are now recorded for B's bond
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, MIN_BOND_AMOUNT);
        assertEq(B_bondStartTime, currentTime);
    }

    function testFirstCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testFirstCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // B creates bond
        createBondForUser(B,  MIN_BOND_AMOUNT);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // B creates bond
       createBondForUser(B, MIN_BOND_AMOUNT);

        // Check NFT total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesBonderNFTBalanceByOne() public {
        // Check A has no NFTs
        uint256 A_NFTBalanceBefore = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceBefore, 0);

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check A now has one NFT
        uint256 A_NFTBalanceAfter = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceAfter, 1);
    }

     function testCreateBondMintsBondNFTWithCorrectIDToBonder() public {
        // Expect revert when checking the owner of id #2, since it hasnt been minted
        vm.expectRevert("ERC721: owner query for nonexistent token");
        bondNFT.ownerOf(2);

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check tokenSupply == 1 and A has NFT id #1
        assertEq(bondNFT.totalMinted(),  1);
        address ownerOfID1 = bondNFT.ownerOf(1);
        assertEq(ownerOfID1, A);

        // B creates bond
        createBondForUser(B, MIN_BOND_AMOUNT);

        // Check owner of NFT id #2 is B
        address ownerOfID2After = bondNFT.ownerOf(2);
        assertEq(ownerOfID2After, B);
    }

    function testCreateBondDepositsLUSDInBAMM() public {
        (, uint256 lusdInBAMMBefore,) = bammSPVault.getLUSDValue();

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        (, uint256 lusdInBAMMAfter,) = bammSPVault.getLUSDValue();

        assertEq(lusdInBAMMAfter, lusdInBAMMBefore + MIN_BOND_AMOUNT);
    }

    function testCreateBondRevertsWithZeroInputAmount() public {
        // A tries to bond 0 LUSD
        vm.startPrank(A);
        lusdToken.approve(address(chickenBondManager), 10e18);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.createBond(0);
    }

    function testCreateBondDoesNotChangePermanentBucket() public {
        uint256 bondAmount = 100e18;

        uint256 permanentLUSD_1 = chickenBondManager.getPermanentLUSD();

        // A creates bond
        createBondForUser(A, bondAmount);
        uint256 bondNFT_A = bondNFT.totalMinted();

        uint256 permanentLUSD_2 = chickenBondManager.getPermanentLUSD();

        assertEq(permanentLUSD_2, permanentLUSD_1);

        // B creates bond
        createBondForUser(B, bondAmount);

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        // A chickens in, creating some permanent liquidity
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondNFT_A);
        vm.stopPrank();

        uint256 permanentLUSD_3 = chickenBondManager.getPermanentLUSD();
        // Check permanent LUSD Bucket is non-zero
        assertGt(permanentLUSD_3, 0);

        // C creates bond
        createBondForUser(C, bondAmount);

        uint256 permanentLUSD_4 = chickenBondManager.getPermanentLUSD();

        // Check permanent buckets have not changed from C's new bond
        assertEq(permanentLUSD_4, permanentLUSD_3);
    }

    // --- chickenOut tests ---

    function testChickenOutReducesTotalPendingLUSD() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        // Get B's bondID
        uint256 B_bondID = bondNFT.totalMinted();

        // get totalPendingLUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.getPendingLUSD();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

       // check totalPendingLUSD decreases by correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore - bondAmount);
    }

    function testChickenOutDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenOutTransferbLUSDToBonder() public {
        // A, B create bond
        uint256 bondAmount = 171e17 + MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B lusd balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertApproximatelyEqual(B_LUSDBalanceAfter, B_LUSDBalanceBefore + bondAmount, 1e3);
    }

    function testChickenOutReducesBondNFTSupplyByOne() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        // Since B was the last bonder, his bond ID is the current total minted
        uint256 B_bondID = bondNFT.totalMinted();
        uint256 nftTokenSupplyBefore = bondNFT.tokenSupply();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 nftTokenSupplyAfter = bondNFT.tokenSupply();

        // Check NFT token supply has decreased by 1
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenOutDoesNotChangeBondNFTTotalMinted() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        // Since B was the last bonder, his bond ID is the current total minted
        uint256 B_bondID = bondNFT.totalMinted();
        uint256 nftTotalMintedBefore = bondNFT.totalMinted();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 nftTotalMintedAfter = bondNFT.totalMinted();

        // Check NFT token minted does not change
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenOutRemovesOwnerOfBondNFT() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B owns bond #2
        assertEq(B_bondID, 2);
        address ownerOfBondID2 = bondNFT.ownerOf(B_bondID);
        assertEq(ownerOfBondID2, B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        // Expect ownerOF bond ID #2 call to revert due to non-existent owner
        vm.expectRevert("ERC721: owner query for nonexistent token");
        ownerOfBondID2 = bondNFT.ownerOf(B_bondID);
    }

    function testChickenOutDecreasesBonderNFTBalanceByOne() public {
        // A, B create bond
        uint256 bondAmount = MIN_BOND_AMOUNT + 37432e15;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B's NFT balance is 1
        uint256 B_NFTBalanceBefore = bondNFT.balanceOf(B);
        assertEq(B_NFTBalanceBefore, 1);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 B_NFTBalanceAfter = bondNFT.balanceOf(B);

        // Check B's NFT balance has decreased by 1
        assertEq(B_NFTBalanceAfter, B_NFTBalanceBefore - 1);
    }

    function testChickenOutRevertsWhenCallerIsNotBonder() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // B tries to chicken out A's bond
        vm.startPrank(B);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(A_bondID, 0);

        // B tries to chicken out non-existent bond
        vm.expectRevert("ERC721: owner query for nonexistent token");
        chickenBondManager.chickenOut(37, 0);
    }

    function testChickenOutRevertsWhenBonderChickensOutBondTheyDontOwn() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // A attempts to chicken out B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(B_bondID, 0);
    }

    function testChickenOutDoesNotChangePermanentBucket() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 bondID_A = bondNFT.totalMinted();

        // time passes
        vm.warp(block.timestamp + 7 days);

        // Get permanent buckets
        uint256 permanentLUSD_1 = chickenBondManager.getPermanentLUSD();

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A, 0);
        vm.stopPrank();

        // Check permanent buckets haven't changed
        uint256 permanentLUSD_2 = chickenBondManager.getPermanentLUSD();
        assertEq(permanentLUSD_2, permanentLUSD_1);

        // B, C create bond
        createBondForUser(B, bondAmount);
        uint256 bondID_B = bondNFT.totalMinted();
        createBondForUser(C, bondAmount);
        uint256 bondID_C = bondNFT.totalMinted();

        // time passes
        vm.warp(block.timestamp + 7 days);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(bondID_B);
        vm.stopPrank();

        // Get permanent buckets, check > 0
        uint256 permanentLUSD_3 = chickenBondManager.getPermanentLUSD();
        // Check LUSD permanent bucket has increased
        assertGt(permanentLUSD_3, 0);

        // C chickens out
        vm.startPrank(C);
        chickenBondManager.chickenOut(bondID_C, 0);
        vm.stopPrank();

        // Check permanent bucekt haven't changed
        uint256 permanentLUSD_4 = chickenBondManager.getPermanentLUSD();
        assertEq(permanentLUSD_4, permanentLUSD_3);
    }

    // --- calcbLUSD Accrual tests ---

    function testCalcAccruedBLUSDReturns0for0StartTime() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        uint256 A_accruedBLUSD = chickenBondManager.calcAccruedBLUSD(A_bondID);
        assertEq(A_accruedBLUSD, 0);
    }

    function testCalcAccruedBLUSDReturnsNonZeroBLUSDForNonZeroInterval(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        uint256 A_accruedBLUSD = chickenBondManager.calcAccruedBLUSD(A_bondID);
        assertTrue(A_accruedBLUSD > 0);

        // --- Test subsequent bond ---

        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Time interval passes
        vm.warp(block.timestamp + _interval);

        // Check accrued bLUSD < bLUSD Cap
        assertTrue(chickenBondManager.calcAccruedBLUSD(B_bondID) < chickenBondManager.calcBondBLUSDCap(B_bondID));
    }

    // TODO: convert to fuzz test
    function testCalcAccruedBLUSDNeverReachesCap(uint256 _interval) public {
         // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        // Check accrued bLUSD < bLUSD Cap
        assertTrue(chickenBondManager.calcAccruedBLUSD(A_bondID) < chickenBondManager.calcBondBLUSDCap(A_bondID));

        // --- Test subsequent bond ---
        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        //B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        // Check accrued bLUSD < bLUSD Cap
        assertTrue(chickenBondManager.calcAccruedBLUSD(B_bondID) < chickenBondManager.calcBondBLUSDCap(B_bondID));
    }

    function testCalcAccruedBLUSDIsMonotonicIncreasingWithTime(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume( _interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        uint256 accruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(bondID_A);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedBLUSD_A = chickenBondManager.calcAccruedBLUSD(bondID_A);
        assertTrue(newAccruedBLUSD_A > accruedBLUSD_A);

        // time passes
        vm.warp(block.timestamp + 30 days);

        // --- Test subsequent bond ---

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        //B creates bond
       createBondForUser(A, bondAmount);

        uint256 bondID_B = bondNFT.totalMinted();

        uint256 accruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(bondID_B);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(bondID_B);
        assertTrue(newAccruedBLUSD_B > accruedBLUSD_B);
    }

    function testCalcBLUSDAccrualReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check A's accrued BLUSD is > 0
        uint256 A_accruedBLUSDBefore = chickenBondManager.calcAccruedBLUSD(A_bondID);
        assertGt(A_accruedBLUSDBefore, 0);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(A_bondID, 0);
        vm.stopPrank();

        // Check A's accrued BLUSD is 0
        uint256 A_accruedBLUSDAfter = chickenBondManager.calcAccruedBLUSD(A_bondID);
        assertEq(A_accruedBLUSDAfter, 0);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        A_bondID = bondNFT.totalMinted();

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check B's accrued bLUSD > 0
        uint256 B_accruedBLUSDBefore = chickenBondManager.calcAccruedBLUSD(B_bondID);
        assertGt(B_accruedBLUSDBefore, 0);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);

        // Check B's accrued bLUSD == 0
        uint256 B_accruedBLUSDAfter = chickenBondManager.calcAccruedBLUSD(B_bondID);
        assertEq(B_accruedBLUSDAfter, 0);
    }

    function testCalcBLUSDAccrualReturns0ForNonBonder() public {
          // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 unusedBondID = bondNFT.totalMinted() + 1;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Check accrued bLUSD for a nonexistent bond is 0
        uint256 accruedBLUSD = chickenBondManager.calcAccruedBLUSD(unusedBondID);
        assertEq(accruedBLUSD, 0);
    }

    // --- calcSystemBackingRatio tests ---

    function testBackingRatioIsOneBeforeFirstChickenIn() public {
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_1, 1e18);

        uint256 bondAmount = 100e18;

        // A creates bond
        createBondForUser(A, bondAmount);

        uint256 backingRatio_2 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_2, 1e18);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 backingRatio_3 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_3, 1e18);
    }

    // --- chickenIn tests ---

    function testChickenInFailsAfterShortBondingInterval() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN() - 1);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        vm.expectRevert("CBM: First chicken in must wait until bootstrap period is over");
        chickenBondManager.chickenIn(A_bondID);
    }

    function testChickenInSucceedsAfterShortBondingInterval(uint256 _interval) public {
        // Interval in range ]bootstrap period, bootstrap period + 1 week[
        uint256 interval = coerce(
            _interval,
            chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN(), // wait at least bootstrap period before chicken-in
            chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN() + 1 weeks // wait at least bootstrap period before chicken-in
        );

        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + interval);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
    }

    function testChickenInDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        tip(address(bLUSDToken), B, 5e18);

        uint256 currentTime = block.timestamp;

       // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenInTransfersAccruedBLUSDToBonder() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B bLUSD balance before
        uint256 B_bLUSDBalanceBefore = bLUSDToken.balanceOf(B);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get B's accrued bLUSD and confirm it is non-zero
        uint256 B_accruedBLUSD = chickenBondManager.calcAccruedBLUSD(B_bondID);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's bLUSD balance has increased by correct amount
        uint256 B_bLUSDBalanceAfter = bLUSDToken.balanceOf(B);
        assertEq(B_bLUSDBalanceAfter, B_bLUSDBalanceBefore + B_accruedBLUSD);
    }

    function testChickenInDoesNotChangeBondHolderLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get B LUSD balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's bLUSD balance has increased by correct amount
        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertEq(B_LUSDBalanceAfter, B_LUSDBalanceBefore);
    }


    function testChickenInDecreasesTotalPendingLUSDByBondAmount() public {
         // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get total pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.getPendingLUSD();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total pending LUSD has increased by correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.getPendingLUSD();
        assertLt(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    function testChickenInIncreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get total pending LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total acquired LUSD has increased by correct amount
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore);
    }

    function testChickenInReducesBondNFTSupplyByOne() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 nftTokenSupplyBefore = bondNFT.tokenSupply();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenInDoesNotChangeTotalMinted() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 nftTotalMintedBefore = bondNFT.totalMinted();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTotalMintedAfter = bondNFT.totalMinted();
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenInDecreasesBonderNFTBalanceByOne() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get B's NFT balance before
        uint256 B_bondNFTBalanceBefore = bondNFT.balanceOf(B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's NFT balance decreases by 1
        uint256 B_bondNFTBalanceAfter = bondNFT.balanceOf(B);
        assertEq(B_bondNFTBalanceAfter, B_bondNFTBalanceBefore - 1);
    }

    function testChickenInRemovesOwnerOfBondNFT() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm bond owner is B
        address bondOwnerBefore = bondNFT.ownerOf(B_bondID);
        assertEq(bondOwnerBefore, B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Expert revert when we check for the owner of a non-existent token
        vm.expectRevert("ERC721: owner query for nonexistent token");
        bondNFT.ownerOf(B_bondID);
    }

    function testChickenInChargesChickenInFee() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        uint256 A_startTime = block.timestamp;
        uint256 A_bondID = createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B creates bond
        uint256 B_startTime = block.timestamp;
        uint256 B_bondID = createBondForUser(B, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // B chickens in
        vm.startPrank(B);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // check rewards contract has received rewards
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), _getChickenInFeeForAmount(bondAmount), 1, "Wrong Chicken In fee diverted to rewards contract");
        // check accrued amount is reduced by Chicken In fee
        assertApproximatelyEqual(
            bLUSDToken.balanceOf(B),
            _getAmountMinusChickenInFee(chickenBondManager.calcAccruedBLUSD(B_startTime, bondAmount, backingRatio, chickenBondManager.calcUpdatedAccrualParameter())),
            1000,
            "Wrong Chicken In fee applied to B"
        );

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // A chickens in
        vm.startPrank(A);
        backingRatio = chickenBondManager.calcSystemBackingRatio();
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check rewards contract has received rewards
        assertApproximatelyEqual(lusdToken.balanceOf(address(curveLiquidityGauge)), 2 * _getChickenInFeeForAmount(bondAmount), 2, "Wrong Chicken In fee diverted to rewards contract");
        // check accrued amount is reduced by Chicken In fee
        assertApproximatelyEqual(
            bLUSDToken.balanceOf(A),
            _getAmountMinusChickenInFee(chickenBondManager.calcAccruedBLUSD(A_startTime, bondAmount, backingRatio, chickenBondManager.calcUpdatedAccrualParameter())),
            1000,
            "Wrong Chicken In fee applied to A"
        );
    }

    function testChickenInRevertsWhenCallerIsNotABonder() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

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
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm bond owner is B
        address bondOwnerBefore = bondNFT.ownerOf(B_bondID);
        assertEq(bondOwnerBefore, B);

        // A tries to chickens in B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenIn(B_bondID);
    }

     function testChickenInIncreasesPermanentLUSDBucket() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();

        uint256 permanentLUSD_1 = chickenBondManager.getPermanentLUSD();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        uint256 permanentLUSD_2 = chickenBondManager.getPermanentLUSD();
        assertGt(permanentLUSD_2, permanentLUSD_1);

        // C creates bond
        createBondForUser(C, bondAmount);
        uint256 C_bondID = bondNFT.totalMinted();

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 permanentLUSD_3 = chickenBondManager.getPermanentLUSD();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Check permanent LUSD bucket has increased
        uint256 permanentLUSD_4 = chickenBondManager.getPermanentLUSD();
        assertGt(permanentLUSD_4, permanentLUSD_3);

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 permanentLUSD_5 = chickenBondManager.getPermanentLUSD();

        // C chickens in
        vm.startPrank(C);
        chickenBondManager.chickenIn(C_bondID);
        vm.stopPrank();

        // Check permanent LUSD bucket has increased
        uint256 permanentLUSD_6 = chickenBondManager.getPermanentLUSD();
        assertGt(permanentLUSD_6, permanentLUSD_5);
    }

    // --- redemption tests ---

    function testRedeemFailsAfterShortPeriod() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        uint256 A_bondID = createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // less than bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM() - 1);

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        vm.expectRevert("CBM: Redemption after first chicken in must wait until bootstrap period is over");
        chickenBondManager.redeem(bLUSDToRedeem, 0);
    }

    function testRedeemDecreasesCallersBLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        // Check B's bLUSD balance has decreased
        uint256 B_bLUSDBalanceAfter = bLUSDToken.balanceOf(B);
        assertTrue(B_bLUSDBalanceAfter < bLUSDBalance);
        assertTrue(B_bLUSDBalanceAfter > 0);
    }

    function testRedeemDecreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();

        // Check total acquired LUSD has decreased and is non-zero
        assertTrue(totalAcquiredLUSDAfter < totalAcquiredLUSDBefore);
        assertTrue(totalAcquiredLUSDAfter > 0);
    }

    function testRedeemDecreasesTotalBLUSDSupply() public {
         // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 totalBLUSDBefore = bLUSDToken.totalSupply();

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        uint256 totalBLUSDAfter = bLUSDToken.totalSupply();

         // Check total bLUSD supply has decreased and is non-zero
        assertTrue(totalBLUSDAfter < totalBLUSDBefore);
        assertTrue(totalBLUSDAfter > 0);
    }

    function testRedeemIncreasesCallersYTokenBalance() public {
        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 B_lusdBalanceBefore = lusdToken.balanceOf(B);

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        uint256 B_lusdBalanceAfter = lusdToken.balanceOf(B);

        // Check B's LUSD Balance has increased
        assertTrue(B_lusdBalanceAfter > B_lusdBalanceBefore);
    }

    function testRedeemDecreasesAcquiredLUSDInSPByCorrectFraction(uint256 redemptionFraction) public {
        redemptionFraction = coerce(redemptionFraction, 1e9, 99e16);

        // 1-r.  Fee goes to permanent
        uint256 expectedFractionRemainingAfterRedemption = 1e18 - redemptionFraction;

        // A creates bond
        uint256 bondAmount = 600e18;

        createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertEq(A_bLUSDBalance, 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertGt(A_bLUSDBalance, 0);

        // A transfers his LUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        assertGt(bLUSDBalance, 0);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        assertEq(bLUSDToken.totalSupply(), bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInSPBefore = chickenBondManager.getAcquiredLUSDInSP();

        // B redeems some bLUSD
        uint256 bLUSDToRedeem = bLUSDBalance * redemptionFraction / 1e18;
        assertGt(bLUSDToRedeem, 0);

        vm.startPrank(B);

        assertEq(bLUSDToRedeem, bLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        // Check acquired LUSD in Yearn has decreased by correct fraction
        uint256 acquiredLUSDInSPAfter = chickenBondManager.getAcquiredLUSDInSP();
        uint256 expectedAcquiredLUSDInSPAfter = acquiredLUSDInSPBefore * expectedFractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLUSDInSPAfter, expectedAcquiredLUSDInSPAfter, 1e9, "Acquired LUSD mismatch");
    }

    // ---
    // Find testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction() in ChickenBondManagerMainnetOnlyTest.t.sol
    // It involves Curve spot price manipulation, therefore it only works in a forked mainnet environment
    // ---

    function testRedeemChargesRedemptionFee() public {
        // A creates bond
        uint256 bondAmount = 100e18;
        uint256 ROUNDING_ERROR = 6000;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Confirm A's bLUSD balance is zero
        uint256 A_bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(A_bLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLUSD balance is non-zero
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        assertTrue(bLUSDBalance > 0);

        // A transfers his LUSD to B
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 B_lusdBalanceBefore = lusdToken.balanceOf(B);
        uint256 backingRatio0 = chickenBondManager.calcSystemBackingRatio();

        //assertEq(chickenBondManager.getTotalAcquiredLUSD(), bLUSDToken.totalSupply());
        assertEq(chickenBondManager.calcRedemptionFeePercentage(0), 0);
        // B redeems
        uint256 bLUSDToRedeem = bLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToRedeem, 0);

        uint256 B_lusdBalanceAfter1 = lusdToken.balanceOf(B);
        uint256 backingRatio1 = chickenBondManager.calcSystemBackingRatio();

        // Check B's Y tokens Balance converted to LUSD has increased by exactly redemption amount after redemption fee,
        // as backing ratio was 1
        uint256 redemptionFraction = bLUSDToRedeem * 1e18 / bLUSDBalance;
        uint256 redemptionFeePercentageExpected = redemptionFraction / chickenBondManager.BETA();
        assertApproximatelyEqual(
            B_lusdBalanceAfter1 - B_lusdBalanceBefore,
            bLUSDToRedeem * (1e18 - redemptionFeePercentageExpected) / 1e18,
            ROUNDING_ERROR,
            "Wrong B Y tokens balance increase after 1st redemption"
        );
        assertApproximatelyEqual(backingRatio1, backingRatio0, ROUNDING_ERROR, "Wrong backing ratio after 1st redemption");

        // B redeems again
        redemptionFraction = 3e18/4;
        chickenBondManager.redeem(bLUSDToken.balanceOf(B) * redemptionFraction / 1e18, 0);
        uint256 B_lusdBalanceAfter2 = lusdToken.balanceOf(B);
        // Check B's Y tokens Balance converted to LUSD has increased by less than redemption amount
        // backing ratio was 1, but redemption fee was non zero
        assertGt(
            bLUSDToRedeem - (B_lusdBalanceAfter2 - B_lusdBalanceAfter1),
            ROUNDING_ERROR,
            "Wrong B Y tokens balance increase after 2nd redemption"
        );
        // Now backing ratio should have increased
        assertApproximatelyEqual(chickenBondManager.calcSystemBackingRatio(), backingRatio1, ROUNDING_ERROR, "Wrong backing ratio after 2nd redemption");
    }

    function testRedeemRevertsWhenCallerHasInsufficientBLUSD() public {
        // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // A transfers some bLUSD to B
        uint256 bLUSDBalance = bLUSDToken.balanceOf(A);
        bLUSDToken.transfer(B, bLUSDBalance);
        assertEq(bLUSDBalance, bLUSDToken.balanceOf(B));
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        uint256 B_bLUSDBalance = bLUSDToken.balanceOf(B);
        assertGt(B_bLUSDBalance, 0);

        // B tries to redeem more LUSD than they have
        vm.startPrank(B);
        //vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.expectRevert("CBM: Cannot redeem below min supply");
        chickenBondManager.redeem(B_bLUSDBalance + 1, 0);

        // Reverts on transfer rather than burn, since it tries to redeem more than the total BLUSD supply, and therefore tries
        // to withdraw more LUSD than is held by the system
        // TODO: Fix. Seems to revert with no reason string (or not catch it)?
        // vm.expectRevert("ERC20: transfer amount exceeds balance");
        // chickenBondManager.redeem(B_bLUSDBalance + bLUSDToken.totalSupply(), 0);
    }

    function testRedeemRevertsWithZeroInputAmount() public {
         // A creates bond
        uint256 bondAmount = 100e18;

       createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // Check B's bLUSD balance is zero
        uint256 B_bLUSDBalance = bLUSDToken.balanceOf(B);
        assertEq(B_bLUSDBalance, 0);

        // B tries to redeem with 0 bLUSD balance
        vm.startPrank(B);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.redeem(0, 0);
    }

    function testFailRedeemRevertsWhenTotalAcquiredLUSDisZero() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());


        // confirm acquired LUSD is 0
        assertEq(chickenBondManager.getTotalAcquiredLUSD(), 0);

        // Cheat: tip 5e18 bLUSD to B
        tip(address(bLUSDToken), B, 5e18);
        uint256 B_bLUSDBalance = bLUSDToken.balanceOf(B);
        assertEq(B_bLUSDBalance, 5e18);

        // B tries to redeem his bLUSD while there is 0 total acquired LUSD
        vm.startPrank(B);
        chickenBondManager.redeem(5e18, 0);
    }

    // Actual Yearn and Curve balance tests

    // function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInSPAndCurveVault() public {}

    // function testShiftLUSDFromCurveToSPIncreasebLUSDInSP() public {}
    // function testShiftLUSDFromCurveToSPDecreasebLUSDInCurve() public {}

    // function testFailShiftLUSDFromCurveToSPWhen0LUSDInCurve() public {}

    // --- Yearn Registry tests ---

    function testCorrectLatestYearnCurveVault() public {
        assertEq(yearnRegistry.latestVault(address(curvePool)), address(yearnCurveVault));
    }

    function testYearnLUSDVaultImmediateDepositAndWithdrawalReturnsAlmostExactDeposit(uint256 _depositAmount) public {
        _depositAmount = coerce(_depositAmount, 10, 1e27);

        // Tip CBM some LUSD
        tip(address(lusdToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LUSD to B.Protocol, as CBM
        vm.startPrank(address(chickenBondManager));
        bammSPVault.deposit(_depositAmount);
        assertEq(lusdToken.balanceOf(address(chickenBondManager)), 0);

        // Artificially withdraw all as CBM
        bammSPVault.withdraw(_depositAmount, address(chickenBondManager));

        // Check that CBM was able to withdraw almost exactly its initial deposit
        assertApproximatelyEqual(_depositAmount, lusdToken.balanceOf(address(chickenBondManager)), 1e3);
    }

    // --- Controller tests ---

    function testControllerAccrualParameterStartsAtTheInitialValue(uint256 _interval) public {
        uint256 interval = coerce(_interval, 0, 5200 weeks);

        uint256 accrualParameter = chickenBondManager.accrualParameter();
        assertEqDecimal(accrualParameter, INITIAL_ACCRUAL_PARAMETER, 18);

        // Accrual parameter should stay constant even if time passes
        vm.warp(block.timestamp + interval);

        // Let some user interact with the system
        createBondForUser(A, 100e18);

        // Accrual parameter should still be the initial value
        accrualParameter = chickenBondManager.accrualParameter();
        assertEqDecimal(accrualParameter, INITIAL_ACCRUAL_PARAMETER, 18);
    }

    // "Time delta" refers to time elapsed since deployment of ChickenBondManager contract
    function _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(
        // average of `bond.startTime - chickenBondManager.deploymentTime` for all active bonds
        uint256 averageStartTimeDelta
    ) internal pure returns (uint256) {
        uint256 target = TARGET_AVERAGE_AGE_SECONDS;
        uint256 adjustmentPeriod = ACCRUAL_ADJUSTMENT_PERIOD_SECONDS;

        // Average age is "sampled" by the controller at the exact timestamps given by the formula:
        // `deploymentTimestamp + n * adjustmentPeriod`, where `n` is integer >= 0.
        // We use `ceilDiv` to calculate the time delta of the first such timestamp where the
        // controller sees an average age that's >= the target.
        return adjustmentPeriod * Math.ceilDiv(averageStartTimeDelta + target, adjustmentPeriod);
    }

    function testControllerDoesNotAdjustWhenAgeOfSingleBondIsBelowTarget(uint256 _interval) public {
        uint256 interval = coerce(
            _interval,
            chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN(), // wait at least bootstrap period before chicken-in
            _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0) - 1
        );

        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + interval);
        chickenInForUser(A, bondID);

        uint256 accrualParameter = chickenBondManager.accrualParameter();
        assertEqDecimal(accrualParameter, INITIAL_ACCRUAL_PARAMETER, 18);
    }

    function testControllerDoesAdjustWhenAgeOfSingleBondIsAboveTarget(uint256 _interval) public {
        uint256 interval = coerce(
            _interval,
            _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0),
            5200 weeks
        );

        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + interval);
        chickenInForUser(A, bondID);

        uint256 accrualParameter = chickenBondManager.accrualParameter();
        assertLtDecimal(accrualParameter, INITIAL_ACCRUAL_PARAMETER, 18);
    }

    function testControllerAdjustsByAccrualAdjustmentRate(uint256 _interval, uint8 _periods) public {
        uint256 interval = coerce(
            _interval,
            _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0) - ACCRUAL_ADJUSTMENT_PERIOD_SECONDS,
            // Don't let `_interval` be too long or `accrualParameter` might bottom out
            52 weeks
        );

        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + interval);
        // Since there's been no user interaction that would update `accrualParameter`, use the read-only
        // helper function to calculate its up-to-date value instead
        uint256 accrualParameterBefore = chickenBondManager.calcUpdatedAccrualParameter();

        // Wait some number of adjustment periods
        vm.warp(block.timestamp + _periods * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);

        chickenInForUser(A, bondID);
        uint256 accrualParameterAfter = chickenBondManager.accrualParameter();

        uint256 expectedAdjustment = 1e18;
        for (uint8 i = 0; i < _periods; ++i) {
            expectedAdjustment = (expectedAdjustment * (1e18 - ACCRUAL_ADJUSTMENT_RATE) + 0.5e18) / 1e18;
        }

        assertApproximatelyEqual(accrualParameterAfter, accrualParameterBefore * expectedAdjustment / 1e18, 1e9);
    }

    function testControllerStopsAdjustingOnceAverageAgeDropsBelowTarget(uint256 _interval) public {
        uint256 interval = coerce(
            _interval,
        // In this test we will:
        //   1. Create a bond.
        //      ... Wait for `interval` seconds ...
        //   2. Sample accrual parameter.
        //      ... Wait one accrual adjustment period ...
        //   3. Expect to see an adjusted accrual parameter.
        //      For this to hold, `interval + ACCRUAL_ADJUSTMENT_PERIOD_SECONDS` must be at least
        //      `_calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0)`, hence the lower bound:
            _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0) - ACCRUAL_ADJUSTMENT_PERIOD_SECONDS,
        //   4. Create a second bond of the same size.
        //      ... Wait one accrual adjustment period ...
        //   5. Expect to see the same accrual parameter as in step #3 (unadjusted).
        //      For this to hold, the average age of both bonds must fall below the target average age.
        //
        // The upper bounds for ages of bonds 1 & 2 as sampled by the controller (they will be lower
        // in case adjustment period is not a divisor of the total waiting time):
        //   age1 <= interval + 2 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS
        //   age2 <= ACCRUAL_ADJUSTMENT_PERIOD_SECONDS
        //
        // So the upper bound for average age is:
        //   avgAge <= (interval + 3 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS) / 2
        //
        // We want the average age to be <= the target. Rearranging:
        //   (interval + 3 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS) / 2 <= TARGET_AVERAGE_AGE_SECONDS
        //   interval + 3 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS <= 2 * TARGET_AVERAGE_AGE_SECONDS
        //   interval <= 2 * TARGET_AVERAGE_AGE_SECONDS - 3 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS
        //
        // Therefore this upper bound for `interval` should work in all cases:
            2 * TARGET_AVERAGE_AGE_SECONDS - 3 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS
        );

        createBondForUser(A, 100e18);
        vm.warp(block.timestamp + interval);
        uint256 accrualParameter1 = chickenBondManager.calcUpdatedAccrualParameter();

        vm.warp(block.timestamp + ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);
        uint256 accrualParameter2 = chickenBondManager.calcUpdatedAccrualParameter();
        assertLtDecimal(accrualParameter2, accrualParameter1, 18);

        createBondForUser(B, 100e18);
        vm.warp(block.timestamp + ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);
        uint256 accrualParameter3 = chickenBondManager.calcUpdatedAccrualParameter();
        assertEqDecimal(accrualParameter3, accrualParameter2, 18);
    }

    struct ArbitraryBondParams {
        uint256 lusdAmount;
        uint256 startTimeDelta;
    }

    function _coerceLUSDAmounts(ArbitraryBondParams[] memory _params, uint256 a, uint256 b) internal pure {
        for (uint256 i = 0; i < _params.length; ++i) {
            _params[i].lusdAmount = coerce(_params[i].lusdAmount, a, b);
        }
    }

    function _coerceStartTimeDeltas(ArbitraryBondParams[] memory _params, uint256 a, uint256 b) internal pure {
        for (uint256 i = 0; i < _params.length; ++i) {
            _params[i].startTimeDelta = coerce(_params[i].startTimeDelta, a, b);
        }
    }

    function _sortStartTimeDeltas(ArbitraryBondParams[] memory _params) internal pure {
        uint256[] memory startTimeDeltas = new uint256[](_params.length);

        for (uint256 i = 0; i < _params.length; ++i) {
            startTimeDeltas[i] = _params[i].startTimeDelta;
        }

        QuickSort.sort(startTimeDeltas);

        for (uint256 i = 0; i < _params.length; ++i) {
            _params[i].startTimeDelta = startTimeDeltas[i];
        }
    }

    function _calcTotalLUSDAmount(ArbitraryBondParams[] memory _params) internal pure returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < _params.length; ++i) {
            total += _params[i].lusdAmount;
        }

        return total;
    }

    function _calcAverageStartTimeDelta(ArbitraryBondParams[] memory _params) internal returns (uint256) {
        uint256 numerator = 0;
        uint256 denominator = 0;

        for (uint256 i = 0; i < _params.length; ++i) {
            numerator += _params[i].lusdAmount * _params[i].startTimeDelta;
            denominator += _params[i].lusdAmount;
        }

        assertGt(denominator, 0);
        return numerator / denominator;
    }

    function testControllerStartsAdjustingWhenAverageAgeOfMultipleBondsStartsExceedingTarget(ArbitraryBondParams[] memory _params) public {
        vm.assume(_params.length > 0);

        _coerceLUSDAmounts(_params, 100e18, 1000e18);
        _coerceStartTimeDeltas(_params, 0, TARGET_AVERAGE_AGE_SECONDS);
        _sortStartTimeDeltas(_params);

        uint256 deploymentTimestamp = chickenBondManager.deploymentTimestamp();
        uint256 prevStartTimeDelta = 0;

        // This test requires more LUSD than the others
        tip(address(lusdToken), A, _calcTotalLUSDAmount(_params));

        for (uint256 i = 0; i < _params.length; ++i) {
            // Make sure we're not about to go back in time
            assertGe(_params[i].startTimeDelta, prevStartTimeDelta);
            vm.warp(deploymentTimestamp + _params[i].startTimeDelta);
            createBondForUser(A, _params[i].lusdAmount);

            prevStartTimeDelta = _params[i].startTimeDelta;
        }

        uint256 averageStartTimeDelta = _calcAverageStartTimeDelta(_params);
        uint256 finalTimeDelta = _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(averageStartTimeDelta);

        // There's a very low chance that we don't have 2 adjustment periods left until the target is exceeded.
        // This can happen if the longest start time delta is close to its upper bound while the average start time delta
        // is close to zero (e.g. because there's a large volume of older bonds vs. a small volume of newer bonds).
        // Just discard such runs.
        vm.assume(finalTimeDelta - 2 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS >= prevStartTimeDelta);

        // Time-travel to 2 periods before the controller is expected to make its first adjustment
        vm.warp(deploymentTimestamp + finalTimeDelta - 2 * ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);
        uint256 accrualParameter1 = chickenBondManager.calcUpdatedAccrualParameter();
        assertEqDecimal(accrualParameter1, INITIAL_ACCRUAL_PARAMETER, 18);

        // Advance one period and expect to see no adjustment yet
        vm.warp(block.timestamp + ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);
        uint256 accrualParameter2 = chickenBondManager.calcUpdatedAccrualParameter();
        assertEqDecimal(accrualParameter2, accrualParameter1, 18);

        // Advance one more period and expect to see a reduced accrual parameter
        vm.warp(block.timestamp + ACCRUAL_ADJUSTMENT_PERIOD_SECONDS);
        uint256 accrualParameter3 = chickenBondManager.calcUpdatedAccrualParameter();
        assertLtDecimal(accrualParameter3, accrualParameter2, 18);
    }

     // --- Shifter countdown tests ---

    function testStartShifterCountdownSetsCountdownStartTime() public {
        vm.warp(block.timestamp + 30 days); // Move time forward so that we're not close to a block.timestamp of 0
        
        uint256 startTime1 = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(startTime1, 0);

        vm.startPrank(A);
        chickenBondManager.startShifterCountdown();

        uint256 startTime2 = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(startTime2, block.timestamp);
    }

    function testStartShifterCountdownRevertsDuringCountdown() public {
        vm.warp(block.timestamp + 30 days); // Move time forward so that we're not close to a block.timestamp of 0
        
        uint256 delay = chickenBondManager.SHIFTER_DELAY();
        uint256 window = chickenBondManager.SHIFTER_WINDOW();

        vm.startPrank(A);
        chickenBondManager.startShifterCountdown();

        uint256 startTime = chickenBondManager.lastShifterCountdownStartTime();
        assertGt(startTime, 0);

        // Fast forward to middle of delay
        vm.warp(startTime + delay / 2);

        console.log(block.timestamp, "block.timestamp");
        console.log(startTime + delay + window, "time it should be allowed");

        vm.expectRevert("CBM: Previous shift delay and window must have passed");
        chickenBondManager.startShifterCountdown();

        // Fast forward to last second of delay
        vm.warp(startTime + delay - 1);
        vm.expectRevert("CBM: Previous shift delay and window must have passed");
        chickenBondManager.startShifterCountdown();
    }

     function testStartShifterCountdownRevertsDuringShiftingWindow() public {
        vm.warp(block.timestamp + 30 days); // Move time forward so that we're not close to a block.timestamp of 0
        
        uint256 delay = chickenBondManager.SHIFTER_DELAY();
        uint256 window = chickenBondManager.SHIFTER_WINDOW();

        vm.startPrank(A);
        chickenBondManager.startShifterCountdown();

        uint256 startTime = chickenBondManager.lastShifterCountdownStartTime();
        assertGt(startTime, 0);

        // Fast forward to middle of shifting window
        vm.warp(startTime + delay + window / 2);

        console.log(block.timestamp, "block.timestamp");
        console.log(startTime + delay + window, "time it should be allowed");

        vm.expectRevert("CBM: Previous shift delay and window must have passed");
        chickenBondManager.startShifterCountdown();

        // Fast forward to last second of shifting window
        vm.warp(startTime + delay + window - 1);
        vm.expectRevert("CBM: Previous shift delay and window must have passed");
        chickenBondManager.startShifterCountdown();
    }

    function testStartShifterCountdownSucceedsAfterShiftingWindow() public {
        vm.warp(block.timestamp + 30 days); // Move time forward so that we're not close to a block.timestamp of 0
        
        uint256 delay = chickenBondManager.SHIFTER_DELAY();
        uint256 window = chickenBondManager.SHIFTER_WINDOW();

        vm.startPrank(A);
        chickenBondManager.startShifterCountdown();

        uint256 startTime1 = chickenBondManager.lastShifterCountdownStartTime();
        assertGt(startTime1, 0);

        // Fast forward to end of shifting window
        vm.warp(startTime1 + delay + window);

        chickenBondManager.startShifterCountdown();

        uint256 startTime2 = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(startTime2, block.timestamp);

        // Fast to after end of latest shifting window
        vm.warp(startTime2 + delay + window + 17 days);
       
        chickenBondManager.startShifterCountdown();

        uint256 startTime3 = chickenBondManager.lastShifterCountdownStartTime();
        assertEq(startTime3, block.timestamp);
    }
}
