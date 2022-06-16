pragma solidity ^0.8.10;

import "./BaseTest.sol";
import "./QuickSort.sol" as QuickSort;

contract LQTYChickenBondManagerTest is BaseTest {
    function testSetupSetsBondNFTAddressInCBM() public {
        assertTrue(address(chickenBondManager.bondNFT()) == address(bondNFT));
    }

    function testSetupSetsCMBAddressInBondNFT() public {
        assertTrue(bondNFT.chickenBondManagerAddress() == address(chickenBondManager));
    }

    function testPickleJarHasInfiniteLQTYApproval() public {
        uint256 allowance = lqtyToken.allowance(address(chickenBondManager), address(pickleJar));
        assertEq(allowance, 2**256 - 1);
    }

    // --- createBond tests ---

    function testNFTEnumerationWorks() public {
        uint256 A_bondId_1 = createBondForUser(A,  1e18);
        createBondForUser(A,  1e18);
        createBondForUser(B,  1e18);
        createBondForUser(B,  1e18);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 1);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 0), 3);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 1), 4);

        // A chickens out the first bond, so it’s removed
        vm.startPrank(A);
        chickenBondManager.chickenOut(A_bondId_1);
        vm.stopPrank();

        createBondForUser(B,  1e18);
        createBondForUser(A,  1e18);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 6);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 0), 3);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 1), 4);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 2), 5);
    }
    function testFirstCreateBondDoesNotChangeBackingRatio() public {
        // Get initial backing ratio
        uint256 backingRatioBefore = chickenBondManager.calcSystemBackingRatio();

        // A approves the system for LQTY transfer and creates the bond
        createBondForUser(A,  25e18);

        // check backing ratio after has not changed
        uint256 backingRatioAfter = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatioAfter, backingRatioBefore);
    }

    function testCreateBondDoesNotChangeBackingRatio() public {
        // A approves the system for LQTY transfer and creates the bond
        createBondForUser(A, 25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get initial backing ratio
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();

        // B approves the system for LQTY transfer and creates the bond
        createBondForUser(B,  25e18);

        // check backing ratio after has not changed
        uint256 backingRatio_2 = chickenBondManager.calcSystemBackingRatio();
        assertApproximatelyEqual(backingRatio_2, backingRatio_1, 1e3);

        vm.warp(block.timestamp + 30 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLQTY = chickenBondManager.getAcquiredLQTY();
        assertGt(totalAcquiredLQTY, 0);

        // Get backing ratio 3
        uint256 backingRatio_3 = chickenBondManager.calcSystemBackingRatio();

        // C creates bond
        createBondForUser(C,  25e18);

        // Check backing ratio is unchanged by the last bond creation
        uint256 backingRatio_4 = chickenBondManager.calcSystemBackingRatio();
        assertApproximatelyEqual(backingRatio_4, backingRatio_3, 1e3);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensIn() public {
        // A approves the system for LQTY transfer and creates the bond
        createBondForUser(A,  20e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LQTY transfer and creates the bond
        createBondForUser(B,  20e18);

        vm.warp(block.timestamp + 1 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLQTY = chickenBondManager.getAcquiredLQTY();
        assertGt(totalAcquiredLQTY, 0);

        // C creates bond
        createBondForUser(C,  25e18);

        uint256 bondID_C = bondNFT.totalMinted();
        (, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);

        // assertEq(bondedLQTY_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensOut() public {
        // A approves the system for LQTY transfer and creates the bond
        createBondForUser(A,  25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LQTY transfer and creates the bond
        createBondForUser(B,  25e18);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A);
        vm.stopPrank();

        uint256 totalPendingLQTY = chickenBondManager.getPendingLQTY();
        assertGt(totalPendingLQTY, 0);

        // C creates bond
        createBondForUser(C,  25e18);

        vm.warp(block.timestamp + 600);

        uint256 bondID_C = bondNFT.totalMinted();
        (uint256 bondedLQTY_C, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);
        assertEq(bondedLQTY_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp - 600);
    }

    function testFirstCreateBondIncreasesTotalPendingLQTY(uint) public {
        // Get initial pending LQTY
        uint256 totalPendingLQTYBefore = chickenBondManager.getPendingLQTY();

        // Confirm initial total pending LQTY is 0
        assertTrue(totalPendingLQTYBefore == 0);

        // A approves the system for LQTY transfer and creates the bond
        createBondForUser(A,  25e18);

        // Check totalPendingLQTY has increased by the correct amount
        uint256 totalPendingLQTYAfter = chickenBondManager.getPendingLQTY();
        assertTrue(totalPendingLQTYAfter == 25e18);
    }

    function testCreateBondIncreasesTotalPendingLQTY() public {
        // First, A creates an initial bond
        createBondForUser(A, 25e18);

        // B creates the bond
        createBondForUser(B, 10e18);

        vm.stopPrank();

        // Check totalPendingLQTY has increased by the correct amount
        uint256 totalPendingLQTYAfter = chickenBondManager.getPendingLQTY();
        assertTrue(totalPendingLQTYAfter == 35e18);
    }

    function testCreateBondReducebLQTYBalanceOfBonder() public {
        // Get A balance before
        uint256 balanceBefore = lqtyToken.balanceOf(A);

        // A creates bond
        createBondForUser(A, 10e18);

        // Check A balance has reduced by correct amount
        uint256 balanceAfter = lqtyToken.balanceOf(A);
        assertEq(balanceBefore - 10e18, balanceAfter);
    }

    function testCreateBondRecordsBondData() public {
        // A creates bond #1
        createBondForUser(A, 10e18);

        // Confirm bond data for bond #2 is 0
        (uint256 B_bondedLQTY, uint256 B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLQTY, 0);
        assertEq(B_bondStartTime, 0);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, 10e18);

        // Check bonded amount and bond start time are now recorded for B's bond
        (B_bondedLQTY, B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLQTY, 10e18);
        assertEq(B_bondStartTime, currentTime);
    }

    function testFirstCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // A creates bond
        createBondForUser(A, 10e18);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testFirstCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // A creates bond
        createBondForUser(A, 10e18);

        // Check total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // A creates bond
        createBondForUser(A, 10e18);

        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.tokenSupply();

        // B creates bond
        createBondForUser(B,  10e18);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // A creates bond
        createBondForUser(A, 10e18);

        // Get NFT total minted before
        uint256 totalMintedBefore = bondNFT.totalMinted();

        // B creates bond
        createBondForUser(B, 10e18);

        // Check NFT total minted after has increased by 1
        uint256 totalMintedAfter = bondNFT.totalMinted();
        assertEq(totalMintedBefore + 1, totalMintedAfter);
    }

    function testCreateBondIncreasesBonderNFTBalanceByOne() public {
        // Check A has no NFTs
        uint256 A_NFTBalanceBefore = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceBefore, 0);

        // A creates bond
        createBondForUser(A, 10e18);

        // Check A now has one NFT
        uint256 A_NFTBalanceAfter = bondNFT.balanceOf(A);
        assertEq(A_NFTBalanceAfter, 1);
    }

    function testCreateBondMintsBondNFTWithCorrectIDToBonder() public {
        // Expect revert when checking the owner of id #2, since it hasnt been minted
        vm.expectRevert("ERC721: invalid token ID");
        bondNFT.ownerOf(2);

        // A creates bond
        createBondForUser(A, 10e18);

        // Check tokenSupply == 1 and A has NFT id #1
        assertEq(bondNFT.totalMinted(),  1);
        address ownerOfID1 = bondNFT.ownerOf(1);
        assertEq(ownerOfID1, A);

        // B creates bond
        createBondForUser(B, 10e18);

        // Check owner of NFT id #2 is B
        address ownerOfID2After = bondNFT.ownerOf(2);
        assertEq(ownerOfID2After, B);
    }

    function testCreateBondTransferbLQTYToPickleJar() public {
        // Get Pickle jar balance before
        uint256 pickleJarBalanceBefore = lqtyToken.balanceOf(address(pickleJar));

        // A creates bond
        createBondForUser(A, 10e18);

        uint256 pickleJarBalanceAfter = lqtyToken.balanceOf(address(pickleJar));

        assertEq(pickleJarBalanceAfter, pickleJarBalanceBefore + 10e18);
    }

    function testCreateBondRevertsWithZeroInputAmount() public {
        // A tries to bond 0 LQTY
        vm.startPrank(A);
        lqtyToken.approve(address(chickenBondManager), 10e18);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.createBond(0);
    }

    function testCreateBondDoesNotChangePermanentBuckets() public {
        uint256 bondAmount = 10e18;

        uint256 permanentLQTY_1 = chickenBondManager.getPermanentLQTY();

        // A creates bond
        createBondForUser(A, bondAmount);
        uint256 bondNFT_A = bondNFT.totalMinted();

        uint256 permanentLQTY_2 = chickenBondManager.getPermanentLQTY();

        assertEq(permanentLQTY_2, permanentLQTY_1);

        // B creates bond
        createBondForUser(B, bondAmount);

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        // A chickens in, creating some permanent liquidity
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondNFT_A);
        vm.stopPrank();

        uint256 permanentLQTY_3 = chickenBondManager.getPermanentLQTY();
        // Check permanent LQTY Bucket is non-zero
        assertGt(permanentLQTY_3, 0);

        // C creates bond
        createBondForUser(C, bondAmount);

        uint256 permanentLQTY_4 = chickenBondManager.getPermanentLQTY();

        // Check permanent buckets have not changed from C's new bond
        assertEq(permanentLQTY_4, permanentLQTY_3);
    }

    // --- chickenOut tests ---

    function testChickenOutReducesTotalPendingLQTY() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        // Get B's bondID
        uint256 B_bondID = bondNFT.totalMinted();

        // get totalPendingLQTY before
        uint256 totalPendingLQTYBefore = chickenBondManager.getPendingLQTY();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        // check totalPendingLQTY decreases by correct amount
        uint256 totalPendingLQTYAfter = chickenBondManager.getPendingLQTY();
        assertEq(totalPendingLQTYAfter, totalPendingLQTYBefore - bondAmount);
    }

    function testChickenOutDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLQTY, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLQTY, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLQTY, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLQTY, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenOutTransferbLQTYToBonder() public {
        // A, B create bond
        uint256 bondAmount = 171e17;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B lqty balance before
        uint256 B_LQTYBalanceBefore = lqtyToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 B_LQTYBalanceAfter = lqtyToken.balanceOf(B);
        assertApproximatelyEqual(B_LQTYBalanceAfter, B_LQTYBalanceBefore + bondAmount, 1e3);
    }

    function testChickenOutReducesBondNFTSupplyByOne() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

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

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

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

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

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
        vm.expectRevert("ERC721: invalid token ID");
        ownerOfBondID2 = bondNFT.ownerOf(B_bondID);
    }

    function testChickenOutDecreasesBonderNFTBalanceByOne() public {
        // A, B create bond
        uint256 bondAmount = 37432e15;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

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

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // B tries to chicken out A's bond
        vm.startPrank(B);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(A_bondID);

        // B tries to chicken out non-existent bond
        vm.expectRevert("ERC721: invalid token ID");
        chickenBondManager.chickenOut(37);
    }

    function testChickenOutRevertsWhenBonderChickensOutBondTheyDontOwn() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // A attempts to chicken out B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(B_bondID);
    }

    function testChickenOutDoesNotChangePermanentBuckets() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 bondID_A = bondNFT.totalMinted();

        // time passes
        vm.warp(block.timestamp + 7 days);

        // Get permanent buckets
        uint256 permanentLQTY_1 = chickenBondManager.getPermanentLQTY();

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A);
        vm.stopPrank();

        // Check permanent buckets haven't changed
        uint256 permanentLQTY_2 = chickenBondManager.getPermanentLQTY();
        assertEq(permanentLQTY_2, permanentLQTY_1);

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
        uint256 permanentLQTY_3 = chickenBondManager.getPermanentLQTY();
        // Check LQTY permanent bucket has increased
        assertGt(permanentLQTY_3, 0);

        // C chickens out
        vm.startPrank(C);
        chickenBondManager.chickenOut(bondID_C);
        vm.stopPrank();

        // Check permanent bucekt haven't changed
        uint256 permanentLQTY_4 = chickenBondManager.getPermanentLQTY();
        assertEq(permanentLQTY_4, permanentLQTY_3);
    }

    // --- calcbLQTY Accrual tests ---

    function testCalcAccruedBLQTYReturns0for0StartTime() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        uint256 A_accruedBLQTY = chickenBondManager.calcAccruedBLQTY(A_bondID);
        assertEq(A_accruedBLQTY, 0);
    }

    function testCalcAccruedBLQTYReturnsNonZeroBLQTYForNonZeroInterval(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        uint256 A_accruedBLQTY = chickenBondManager.calcAccruedBLQTY(A_bondID);
        assertTrue(A_accruedBLQTY > 0);

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

        // Check accrued bLQTY < bLQTY Cap
        assertTrue(chickenBondManager.calcAccruedBLQTY(B_bondID) < chickenBondManager.calcBondBLQTYCap(B_bondID));
    }

    // TODO: convert to fuzz test
    function testCalcAccruedBLQTYNeverReachesCap(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        // Check accrued bLQTY < bLQTY Cap
        assertTrue(chickenBondManager.calcAccruedBLQTY(A_bondID) < chickenBondManager.calcBondBLQTYCap(A_bondID));

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

        // Check accrued bLQTY < bLQTY Cap
        assertTrue(chickenBondManager.calcAccruedBLQTY(B_bondID) < chickenBondManager.calcBondBLQTYCap(B_bondID));
    }

    function testCalcAccruedBLQTYIsMonotonicIncreasingWithTime(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume( _interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        uint256 accruedBLQTY_A = chickenBondManager.calcAccruedBLQTY(bondID_A);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedBLQTY_A = chickenBondManager.calcAccruedBLQTY(bondID_A);
        assertTrue(newAccruedBLQTY_A > accruedBLQTY_A);

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

        uint256 accruedBLQTY_B = chickenBondManager.calcAccruedBLQTY(bondID_B);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedBLQTY_B = chickenBondManager.calcAccruedBLQTY(bondID_B);
        assertTrue(newAccruedBLQTY_B > accruedBLQTY_B);
    }

    function testCalcBLQTYAccrualReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check A's accrued BLQTY is > 0
        uint256 A_accruedBLQTYBefore = chickenBondManager.calcAccruedBLQTY(A_bondID);
        assertGt(A_accruedBLQTYBefore, 0);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(A_bondID);
        vm.stopPrank();

        // Check A's accrued BLQTY is 0
        uint256 A_accruedBLQTYAfter = chickenBondManager.calcAccruedBLQTY(A_bondID);
        assertEq(A_accruedBLQTYAfter, 0);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        A_bondID = bondNFT.totalMinted();

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check B's accrued bLQTY > 0
        uint256 B_accruedBLQTYBefore = chickenBondManager.calcAccruedBLQTY(B_bondID);
        assertGt(B_accruedBLQTYBefore, 0);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);

        // Check B's accrued bLQTY == 0
        uint256 B_accruedBLQTYAfter = chickenBondManager.calcAccruedBLQTY(B_bondID);
        assertEq(B_accruedBLQTYAfter, 0);
    }

    function testCalcBLQTYAccrualReturns0ForNonBonder() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 unusedBondID = bondNFT.totalMinted() + 1;

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Check accrued bLQTY for a nonexistent bond is 0
        uint256 accruedBLQTY = chickenBondManager.calcAccruedBLQTY(unusedBondID);
        assertEq(accruedBLQTY, 0);
    }

    // --- calcSystemBackingRatio tests ---

    function testBackingRatioIsOneBeforeFirstChickenIn() public {
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatio_1, 1e18);

        uint256 bondAmount = 10e18;

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

    function testChickenInSucceedsAfterShortBondingInterval(uint256 _interval) public {
        vm.assume(_interval > 1  && _interval < 1 weeks); // Interval in range [1 second, 1 week]

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + _interval);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
    }

    function testChickenInDeletesBondData() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        tip(address(bLQTYToken), B, 5e18);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Confirm B has correct bond data
        (uint256 B_bondedLQTY, uint256 B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLQTY, bondAmount);
        assertEq(B_bondStartTime, currentTime);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLQTY, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLQTY, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenInTransfersAccruedBLQTYToBonder() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B bLQTY balance before
        uint256 B_bLQTYBalanceBefore = bLQTYToken.balanceOf(B);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get B's accrued bLQTY and confirm it is non-zero
        uint256 B_accruedBLQTY = chickenBondManager.calcAccruedBLQTY(B_bondID);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's bLQTY balance has increased by correct amount
        uint256 B_bLQTYBalanceAfter = bLQTYToken.balanceOf(B);
        assertEq(B_bLQTYBalanceAfter, B_bLQTYBalanceBefore + B_accruedBLQTY);
    }

    function testChickenInDoesNotChangeBondHolderLQTYBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get B LQTY balance before
        uint256 B_LQTYBalanceBefore = lqtyToken.balanceOf(B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's bLQTY balance has increased by correct amount
        uint256 B_LQTYBalanceAfter = lqtyToken.balanceOf(B);
        assertEq(B_LQTYBalanceAfter, B_LQTYBalanceBefore);
    }


    function testChickenInDecreasesTotalPendingLQTYByBondAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get total pending LQTY before
        uint256 totalPendingLQTYBefore = chickenBondManager.getPendingLQTY();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total pending LQTY has increased by correct amount
        uint256 totalPendingLQTYAfter = chickenBondManager.getPendingLQTY();
        assertLt(totalPendingLQTYAfter, totalPendingLQTYBefore);
    }

    function testChickenInIncreasesTotalAcquiredLQTY() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get total pending LQTY before
        uint256 totalAcquiredLQTYBefore = chickenBondManager.getAcquiredLQTY();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total acquired LQTY has increased by correct amount
        uint256 totalAcquiredLQTYAfter = chickenBondManager.getAcquiredLQTY();
        assertGt(totalAcquiredLQTYAfter, totalAcquiredLQTYBefore);
    }

    function testChickenInReducesBondNFTSupplyByOne() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 nftTokenSupplyBefore = bondNFT.tokenSupply();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTokenSupplyAfter = bondNFT.tokenSupply();
        assertEq(nftTokenSupplyAfter, nftTokenSupplyBefore - 1);
    }

    function testChickenInDoesNotChangeTotalMinted() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 nftTotalMintedBefore = bondNFT.totalMinted();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTotalMintedAfter = bondNFT.totalMinted();
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenInDecreasesBonderNFTBalanceByOne() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

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
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm bond owner is B
        address bondOwnerBefore = bondNFT.ownerOf(B_bondID);
        assertEq(bondOwnerBefore, B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Expert revert when we check for the owner of a non-existent token
        vm.expectRevert("ERC721: invalid token ID");
        bondNFT.ownerOf(B_bondID);
    }

    function testChickenInChargesChickenInFee() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        uint256 A_startTime = block.timestamp;
        uint256 A_bondID = createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // B creates bond
        uint256 B_startTime = block.timestamp;
        uint256 B_bondID = createBondForUser(B, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // B chickens in
        vm.startPrank(B);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // check rewards contract has received rewards
        assertApproximatelyEqual(
            lqtyToken.balanceOf(address(curveLiquidityGauge)),
            _getChickenInFeeForAmount(bondAmount),
            10,
            "Wrong Chicken In fee diverted to rewards contract"
        );
        // check accrued amount is reduced by Chicken In fee
        assertApproximatelyEqual(
            bLQTYToken.balanceOf(B),
            _getAmountMinusChickenInFee(chickenBondManager.calcAccruedBLQTY(B_startTime, bondAmount, backingRatio, chickenBondManager.calcUpdatedAccrualParameter())),
            1000,
            "Wrong Chicken In fee applied to B"
        );

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        backingRatio = chickenBondManager.calcSystemBackingRatio();
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check rewards contract has received rewards
        assertApproximatelyEqual(lqtyToken.balanceOf(
                address(curveLiquidityGauge)),
            2 * _getChickenInFeeForAmount(bondAmount),
            10,
            "Wrong Chicken In fee diverted to rewards contract"
        );
        // check accrued amount is reduced by Chicken In fee
        assertApproximatelyEqual(
            bLQTYToken.balanceOf(A),
            _getAmountMinusChickenInFee(chickenBondManager.calcAccruedBLQTY(A_startTime, bondAmount, backingRatio, chickenBondManager.calcUpdatedAccrualParameter())),
            1000,
            "Wrong Chicken In fee applied to A"
        );
    }

    function testChickenInRevertsWhenCallerIsNotABonder() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

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
        vm.expectRevert("ERC721: invalid token ID");
        chickenBondManager.chickenIn(37);
    }

    function testChickenInRevertsWhenBonderChickensInBondTheyDontOwn() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        createBondForUser(B, bondAmount);

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

    function testChickenInIncreasesPermanentBucket() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();

        uint256 permanentLQTY_1 = chickenBondManager.getPermanentLQTY();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        uint256 permanentLQTY_2 = chickenBondManager.getPermanentLQTY();
        assertGt(permanentLQTY_2, permanentLQTY_1);

        // C creates bond
        createBondForUser(C, bondAmount);
        uint256 C_bondID = bondNFT.totalMinted();

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 permanentLQTY_3 = chickenBondManager.getPermanentLQTY();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // Check permanent LQTY bucket has increased
        uint256 permanentLQTY_4 = chickenBondManager.getPermanentLQTY();
        assertGt(permanentLQTY_4, permanentLQTY_3);

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        uint256 permanentLQTY_5 = chickenBondManager.getPermanentLQTY();

        // C chickens in
        vm.startPrank(C);
        chickenBondManager.chickenIn(C_bondID);
        vm.stopPrank();

        // Check permanent LQTY bucket has increased
        uint256 permanentLQTY_6 = chickenBondManager.getPermanentLQTY();
        assertGt(permanentLQTY_6, permanentLQTY_5);
    }

    // --- redemption tests ---

    function testRedeemDecreasesCallersBLQTYBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLQTYToRedeem);

        // Check B's bLQTY balance has decreased
        uint256 B_bLQTYBalanceAfter = bLQTYToken.balanceOf(B);
        assertTrue(B_bLQTYBalanceAfter < bLQTYBalance);
        assertTrue(B_bLQTYBalanceAfter > 0);
    }

    function testRedeemDecreasesTotalAcquiredLQTY() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        uint256 totalAcquiredLQTYBefore = chickenBondManager.getAcquiredLQTY();

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLQTYToRedeem);

        uint256 totalAcquiredLQTYAfter = chickenBondManager.getAcquiredLQTY();

        // Check total acquired LQTY has decreased and is non-zero
        assertTrue(totalAcquiredLQTYAfter < totalAcquiredLQTYBefore);
        assertTrue(totalAcquiredLQTYAfter > 0);
    }

    function testRedeemDecreasesTotalBLQTYSupply() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        uint256 totalBLQTYBefore = bLQTYToken.totalSupply();

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLQTYToRedeem);

        uint256 totalBLQTYAfter = bLQTYToken.totalSupply();

        // Check total bLQTY supply has decreased and is non-zero
        assertTrue(totalBLQTYAfter < totalBLQTYBefore);
        assertTrue(totalBLQTYAfter > 0);
    }

    function testRedeemIncreasesCallersYTokenBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        uint256 B_pTokensBalanceBefore = pickleJar.balanceOf(B);

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLQTYToRedeem);

        uint256 B_pTokensBalanceAfter = pickleJar.balanceOf(B);

        // Check B's LQTY Balance has increased
        assertTrue(B_pTokensBalanceAfter > B_pTokensBalanceBefore);
    }

    function testRedeemDecreasesAcquiredLQTYInPickleJarByCorrectFraction(uint256 redemptionFraction) public {
        vm.assume(redemptionFraction <= 1e18 && redemptionFraction >= 1e9);
        // uint256 redemptionFraction = 5e17; // 50%
        uint256 percentageFee = chickenBondManager.calcRedemptionFeePercentage(redemptionFraction);
        // 1-r(1-f).  Fee is left inside system
        uint256 expectedFractionRemainingAfterRedemption = 1e18 - (redemptionFraction * (1e18 - percentageFee)) / 1e18;
        // Ensure the expected remaining is between 0 and 100%
        assertTrue(expectedFractionRemainingAfterRedemption > 0 && expectedFractionRemainingAfterRedemption < 1e18);

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertEq(A_bLQTYBalance, 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertGt(A_bLQTYBalance, 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        assertGt(bLQTYBalance, 0);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        assertEq(bLQTYToken.totalSupply(), bLQTYToken.balanceOf(B));
        vm.stopPrank();

        // Get acquired LQTY in Pickle before
        uint256 acquiredLQTYBefore = chickenBondManager.getAcquiredLQTY();

        // B redeems some bLQTY
        uint256 bLQTYToRedeem = bLQTYBalance * redemptionFraction / 1e18;

        assertGt(bLQTYToRedeem, 0);

        assertTrue(bLQTYToRedeem != 0);
        vm.startPrank(B);

        assertEq(bLQTYToRedeem, bLQTYToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(bLQTYToRedeem);

        // Check acquired LQTY in Pickle has decreased by correct fraction
        uint256 acquiredLQTYAfter = chickenBondManager.getAcquiredLQTY();
        uint256 expectedAcquiredLQTYAfter = acquiredLQTYBefore * expectedFractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLQTYAfter, expectedAcquiredLQTYAfter, 1e9);
    }

    function testRedeemChargesRedemptionFee() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 ROUNDING_ERROR = 6000;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's bLQTY balance is zero
        uint256 A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's bLQTY balance is non-zero
        A_bLQTYBalance = bLQTYToken.balanceOf(A);
        assertTrue(A_bLQTYBalance > 0);

        // A transfers his LQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        uint256 B_pTokensBalanceBefore = pickleJar.balanceOf(B);
        uint256 backingRatio0 = chickenBondManager.calcSystemBackingRatio();

        //assertEq(chickenBondManager.getAcquiredLQTY(), bLQTYToken.totalSupply());
        assertEq(chickenBondManager.calcRedemptionFeePercentage(0), 0);
        // B redeems
        uint256 bLQTYToRedeem = bLQTYBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(bLQTYToRedeem);

        uint256 B_pTokensBalanceAfter1 = pickleJar.balanceOf(B);
        uint256 backingRatio1 = chickenBondManager.calcSystemBackingRatio();

        // Check B's Y tokens Balance converted to LQTY has increased by exactly redemption amount after redemption fee,
        // as backing ratio was 1
        uint256 redemptionFraction = bLQTYToRedeem * 1e18 / bLQTYBalance;
        uint256 redemptionFeePercentageExpected = redemptionFraction / chickenBondManager.BETA();
        assertApproximatelyEqual(
            (B_pTokensBalanceAfter1 - B_pTokensBalanceBefore) * pickleJar.getRatio() / 1e18,
            bLQTYToRedeem * (1e18 - redemptionFeePercentageExpected) / 1e18,
            ROUNDING_ERROR,
            "Wrong B Y tokens balance increase after 1st redemption"
        );
        uint256 backingRatioExpected = backingRatio0 * (1e18 - redemptionFraction * (1e18 - redemptionFeePercentageExpected)/1e18)
            / (1e18 - redemptionFraction);
        assertApproximatelyEqual(backingRatio1, backingRatioExpected, ROUNDING_ERROR, "Wrong backing ratio after 1st redemption");

        // B redeems again
        redemptionFraction = 3e18/4;
        chickenBondManager.redeem(bLQTYToken.balanceOf(B) * redemptionFraction / 1e18);
        uint256 B_pTokensBalanceAfter2 = pickleJar.balanceOf(B);
        redemptionFeePercentageExpected = redemptionFeePercentageExpected + redemptionFraction / chickenBondManager.BETA();
        backingRatioExpected = backingRatio1 * (1e18 - redemptionFraction * (1e18 - redemptionFeePercentageExpected)/1e18)
            / (1e18 - redemptionFraction);
        // Check B's Y tokens Balance converted to LQTY has increased by less than redemption amount
        // backing ratio was 1, but redemption fee was non zero
        assertGt(
            bLQTYToRedeem - (B_pTokensBalanceAfter2 - B_pTokensBalanceAfter1) * pickleJar.getRatio() / 1e18,
            ROUNDING_ERROR,
            "Wrong B Y tokens balance increase after 2nd redemption"
        );
        // Now backing ratio should have increased
        assertApproximatelyEqual(chickenBondManager.calcSystemBackingRatio(), backingRatioExpected, ROUNDING_ERROR, "Wrong backing ratio after 2nd redemption");
    }

    function testRedeemRevertsWhenCallerHasInsufficientBLQTY() public {
        // A and B create bonds
        uint256 bondAmount = 10e18;

        uint256 A_bondID = createBondForUser(A, bondAmount);
        uint256 B_bondID = createBondForUser(B, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A and B chicken in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);
        vm.stopPrank();

        // A transfers some bLQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(B);
        vm.startPrank(A);
        bLQTYToken.transfer(B, 1);
        vm.stopPrank();
        assertEq(bLQTYToken.balanceOf(B), bLQTYBalance + 1);

        // B tries to redeem more LQTY than they have
        vm.startPrank(B);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        chickenBondManager.redeem(bLQTYBalance + 2);
    }

    function testRedeemRevertsWhenAmountIsBiggerThanSupply() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // A transfers some bLQTY to B
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.transfer(B, bLQTYBalance);
        assertEq(bLQTYBalance, bLQTYToken.balanceOf(B));
        vm.stopPrank();

        uint256 B_bLQTYBalance = bLQTYToken.balanceOf(B);
        assertGt(B_bLQTYBalance, 0);

        // B tries to redeem more LQTY than they have
        vm.startPrank(B);
        vm.expectRevert("Amount to redeem bigger than total supply");
        chickenBondManager.redeem(B_bLQTYBalance + 1);
    }

    function testRedeemRevertsWithZeroInputAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Check B's bLQTY balance is zero
        uint256 B_bLQTYBalance = bLQTYToken.balanceOf(B);
        assertEq(B_bLQTYBalance, 0);

        // B tries to redeem with 0 bLQTY balance
        vm.startPrank(B);
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.redeem(0);
    }

    function testFailRedeemRevertsWhenTotalAcquiredLQTYisZero() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // confirm acquired LQTY is 0
        assertEq(chickenBondManager.getAcquiredLQTY(), 0);

        // Cheat: tip 5e18 bLQTY to B
        tip(address(bLQTYToken), B, 5e18);
        uint256 B_bLQTYBalance = bLQTYToken.balanceOf(B);
        assertEq(B_bLQTYBalance, 5e18);

        // B tries to redeem his bLQTY while there is 0 total acquired LQTY
        vm.startPrank(B);
        chickenBondManager.redeem(5e18);
    }

    // --- calcTotalPickleJarShareValue tests ---

    function testCalcPickleJarShareValueGivesCorrectAmountAtFirstDepositPartialWithdrawal(uint256 _denominator) public {
       // Assume we withdraw something between full amount and 1 billion'th.  At some point, the denominator would become
       // too large, the share amount too small to withdraw any LQTY, and the withdrawal will revert.
        vm.assume(_denominator > 0 && _denominator < 1e9);

        uint256 depositAmount = 10e18;
        // Tip CBM some LQTY
        tip(address(lqtyToken), address(chickenBondManager), depositAmount);

        // Artificially deposit LQTY to Pickle, as CBM
        vm.startPrank(address(chickenBondManager));
        pickleJar.deposit(depositAmount);
        assertEq(lqtyToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLQTYValue = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(CBMShareLQTYValue, 0);

        // Artificially withdraw fraction of the shares
        uint256 shares = pickleJar.balanceOf(address(chickenBondManager));
        pickleJar.withdraw(shares / _denominator);

        // Check that the CBM received correct fraction of the shares
        uint256 lqtyBalAfter = lqtyToken.balanceOf(address(chickenBondManager));
        uint256 fractionalCBMShareValue = CBMShareLQTYValue / _denominator;

        assertApproximatelyEqual(lqtyBalAfter, fractionalCBMShareValue, 1e3);
    }

    function testCalcPickleJarShareValueGivesCorrectAmountAtFirstDepositFullWithdrawal() public {
        // Assume  10 wei < deposit  (For very tiny deposits <10wei, the Pickle jar share calculation can  round to 0).
        // vm.assume(_depositAmount > 10);

        uint256 _depositAmount = 6013798781155418312;

        // Tip CBM some LQTY
        tip(address(lqtyToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LQTY to Pickle, as CBM
        vm.startPrank(address(chickenBondManager));
        pickleJar.deposit(_depositAmount);
        assertEq(lqtyToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLQTYValue = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(CBMShareLQTYValue, 0);

        // Artifiiually withdraw all the share value as CBM
        uint256 shares = pickleJar.balanceOf(address(chickenBondManager));
        pickleJar.withdraw(shares);

        // Check that the CBM received approximately and at least all of it's share value
        assertGeAndWithinRange(lqtyToken.balanceOf(address(chickenBondManager)), CBMShareLQTYValue, 1e3);
    }

    function testCalcPickleJarShareValueGivesCorrectAmountAtSubsequentDepositFullWithdrawal(uint256 _depositAmount) public {
        // Assume  10 wei < deposit  (For very tiny deposits <10wei, the Pickle jar share calculation can  round to 0).
        // Assume  deposit < 2^128 (3.4e38) (For very large deposits, overflow would occur)
        vm.assume(_depositAmount > 10 && _depositAmount < 2**128);

        // Tip CBM some LQTY
        tip(address(lqtyToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LQTY to Pickle, as CBM
        vm.startPrank(address(chickenBondManager));
        pickleJar.deposit(_depositAmount);
        assertEq(lqtyToken.balanceOf(address(chickenBondManager)), 0);

        // Calc share value
        uint256 CBMShareLQTYValue = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(CBMShareLQTYValue, 0);

        // Artificually withdraw all the share value as CBM
        uint256 shares = pickleJar.balanceOf(address(chickenBondManager));
        pickleJar.withdraw(shares);

        // Check that the CBM received at least all of it's share value
        assertGe(lqtyToken.balanceOf(address(chickenBondManager)), CBMShareLQTYValue, "CBM received less LQTY");
        assertRelativeError(lqtyToken.balanceOf(address(chickenBondManager)), CBMShareLQTYValue, 1e9, "LQTY balance error too big");
    }

    // Test calculated share value does not change over time, ceteris paribus
    function testCalcPickleJarShareValueDoesNotChangeOverTimeAllElseEqual() public {
        uint256 bondAmount = 10e18;

        // A creates bond
        createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get share value 1
        uint256 lqtyPickleJarshareValue_1 = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(lqtyPickleJarshareValue_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 2 == share value 1
        uint256 lqtyPickleJarshareValue_2 = chickenBondManager.calcTotalPickleJarShareValue();
        assertEq(lqtyPickleJarshareValue_2, lqtyPickleJarshareValue_1);

        // B creates bond
        createBondForUser(B, bondAmount);

        // Get share value 3
        uint256 lqtyPickleJarshareValue_3 = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(lqtyPickleJarshareValue_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 4 == share value 3
        uint256 lqtyPickleJarshareValue_4 = chickenBondManager.calcTotalPickleJarShareValue();
        assertEq(lqtyPickleJarshareValue_4, lqtyPickleJarshareValue_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);

        // Get share value 5
        uint256 lqtyPickleJarshareValue_5 = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(lqtyPickleJarshareValue_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check share value 5 == share value 6
         uint256 lqtyPickleJarshareValue_6 = chickenBondManager.calcTotalPickleJarShareValue();
        assertEq(lqtyPickleJarshareValue_6, lqtyPickleJarshareValue_5);
    }

    // Test totalShares does not change over time ceteris paribus
    function testPickleTotalLQTYPTokensDoesNotChangeOverTimeAllElseEqual() public {
        uint256 bondAmount = 10e18;

        // A creates bond
        createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get total pTokens 1
        uint256 pTokensPickleJar_1 = pickleJar.totalSupply();
        assertGt(pTokensPickleJar_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total pTokens 2 == total pTokens 1
        uint256 pTokensPickleJar_2 = pickleJar.totalSupply();
        assertEq(pTokensPickleJar_2, pTokensPickleJar_1);

        // B creates bond
        createBondForUser(B, bondAmount);

        // Get total pTokens  3
        uint256 pTokensPickleJar_3 = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(pTokensPickleJar_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total pTokens 4 == total pTokens 3
        uint256 pTokensPickleJar_4 = chickenBondManager.calcTotalPickleJarShareValue();
        assertEq(pTokensPickleJar_4, pTokensPickleJar_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);

        // Get total pTokens 5
        uint256 pTokensPickleJar_5 = chickenBondManager.calcTotalPickleJarShareValue();
        assertGt(pTokensPickleJar_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total pTokens 5 == total pTokens 6
         uint256 pTokensPickleJar_6 = chickenBondManager.calcTotalPickleJarShareValue();
        assertEq(pTokensPickleJar_6, pTokensPickleJar_5);
    }

    // Test CBM shares does not change over time ceteris paribus
    function testCBMPickleJarPTokensDoesNotChangeOverTimeAllElseEqual() public {
        uint256 bondAmount = 10e18;

        // A creates bond
        createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get CBM pTokens 1
        uint256 CBMpTokensPickleJar_1 = pickleJar.balanceOf(address(chickenBondManager));
        assertGt(CBMpTokensPickleJar_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM PTokens 2 ==  CBM pTokens 1
        uint256 CBMpTokensPickleJar_2 = pickleJar.balanceOf(address(chickenBondManager));
        assertEq(CBMpTokensPickleJar_2, CBMpTokensPickleJar_1);

        // B creates bond
        createBondForUser(B, bondAmount);

        // Get CBM pTokens 3
        uint256 CBMpTokensPickleJar_3 = pickleJar.balanceOf(address(chickenBondManager));
        assertGt(CBMpTokensPickleJar_3, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM pTokens 4 == CBM pTokens 3
        uint256 CBMpTokensPickleJar_4 = pickleJar.balanceOf(address(chickenBondManager));
        assertEq(CBMpTokensPickleJar_4, CBMpTokensPickleJar_3);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);

        // Get CBM pTokens 5
        uint256 CBMpTokensPickleJar_5 = pickleJar.balanceOf(address(chickenBondManager));
        assertGt(CBMpTokensPickleJar_5, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check CBM pTokens 5 == CBM pTokens 6
        uint256 CBMpTokensPickleJar_6 = pickleJar.balanceOf(address(chickenBondManager));
        assertEq(CBMpTokensPickleJar_6, CBMpTokensPickleJar_5);
    }

    function testPickleJarImmediateDepositAndWithdrawalReturnsAlmostExactDeposit(uint256 _depositAmount) public {
        // Assume  10 wei < deposit  (For very tiny deposits <10wei, the Pickle jar share calculation can  round to 0).
        // Assume  deposit < 2^128 (3.4e38) (For very large deposits, overflow would occur)
        vm.assume(_depositAmount > 10 && _depositAmount < 2**128);

        // Tip CBM some LQTY
        tip(address(lqtyToken), address(chickenBondManager), _depositAmount);

        // Artificially deposit LQTY to Pickle, as CBM
        vm.startPrank(address(chickenBondManager));
        pickleJar.deposit(_depositAmount);
        assertEq(lqtyToken.balanceOf(address(chickenBondManager)), 0);

        // Artifiiually withdraw all the share value as CBM
        uint256 shares = pickleJar.balanceOf(address(chickenBondManager));
        pickleJar.withdraw(shares);

        // Check that CBM was able to withdraw almost exactly its initial deposit
        assertApproximatelyEqual(_depositAmount, lqtyToken.balanceOf(address(chickenBondManager)), 1e3);
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
            0,
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
        uint256 lqtyAmount;
        uint256 startTimeDelta;
    }

    function _coerceLQTYAmounts(ArbitraryBondParams[] memory _params, uint256 a, uint256 b) internal pure {
        for (uint256 i = 0; i < _params.length; ++i) {
            _params[i].lqtyAmount = coerce(_params[i].lqtyAmount, a, b);
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

    function _calcTotalLQTYAmount(ArbitraryBondParams[] memory _params) internal pure returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < _params.length; ++i) {
            total += _params[i].lqtyAmount;
        }

        return total;
    }

    function _calcAverageStartTimeDelta(ArbitraryBondParams[] memory _params) internal returns (uint256) {
        uint256 numerator = 0;
        uint256 denominator = 0;

        for (uint256 i = 0; i < _params.length; ++i) {
            numerator += _params[i].lqtyAmount * _params[i].startTimeDelta;
            denominator += _params[i].lqtyAmount;
        }

        assertGt(denominator, 0);
        return numerator / denominator;
    }

    function testControllerStartsAdjustingWhenAverageAgeOfMultipleBondsStartsExceedingTarget(ArbitraryBondParams[] memory _params) public {
        vm.assume(_params.length > 0);

        _coerceLQTYAmounts(_params, 100e18, 1000e18);
        _coerceStartTimeDeltas(_params, 0, TARGET_AVERAGE_AGE_SECONDS);
        _sortStartTimeDeltas(_params);

        uint256 deploymentTimestamp = chickenBondManager.deploymentTimestamp();
        uint256 prevStartTimeDelta = 0;

        // This test requires more LQTY than the others
        tip(address(lqtyToken), A, _calcTotalLQTYAmount(_params));

        for (uint256 i = 0; i < _params.length; ++i) {
            // Make sure we're not about to go back in time
            assertGe(_params[i].startTimeDelta, prevStartTimeDelta);
            vm.warp(deploymentTimestamp + _params[i].startTimeDelta);
            createBondForUser(A, _params[i].lqtyAmount);

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
}
