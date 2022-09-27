
pragma solidity ^0.8.10;

import "./BaseTest.sol";
import "./QuickSort.sol" as QuickSort;

contract ChickenBondManagerTest is BaseTest {
    function testSetupSetsBondNFTAddressInCBM() public {
        assertTrue(address(chickenBondManager.bondNFT()) == address(bondNFT));
    }

    function testSetupSetsCMBAddressInBondNFT() public {
        assertTrue(address(bondNFT.chickenBondManager()) == address(chickenBondManager));
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
        createBondForUser(A, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(A, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);

        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 1);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 0), 3);
        assertEq(bondNFT.tokenOfOwnerByIndex(B, 1), 4);

        createBondForUser(B, MIN_BOND_AMOUNT + 1e18);
        createBondForUser(A, MIN_BOND_AMOUNT + 1e18);

        assertEq(bondNFT.tokenOfOwnerByIndex(A, 0), 1);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 1), 2);
        assertEq(bondNFT.tokenOfOwnerByIndex(A, 2), 6);
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

        uint256 bondID_A = bondNFT.totalSupply();

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

        uint256 bondID_A = bondNFT.totalSupply();

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

        uint256 bondID_C = bondNFT.totalSupply();
        (,, uint256 bondStartTime_C,,) = chickenBondManager.getBondData(bondID_C);

        // assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensOut() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, MIN_BOND_AMOUNT + 25e18);

        uint256 bondID_A = bondNFT.totalSupply();

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

        uint256 bondID_C = bondNFT.totalSupply();
        (uint256 bondedLUSD_C, uint256 claimedBLUSD_C, uint256 bondStartTime_C,,) = chickenBondManager.getBondData(bondID_C);
        assertEq(bondedLUSD_C, MIN_BOND_AMOUNT + 25e18);
        assertEq(claimedBLUSD_C, 0);
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
        (uint256 B_bondedLUSD, uint256 B_claimedBLUSD, uint256 B_bondStartTime,, uint8 B_bondStatus) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_claimedBLUSD, 0);
        assertEq(B_bondStartTime, 0);
        assertEq(B_bondStatus, uint8(IChickenBondManager.BondStatus.nonExistent));

        (
            uint80 B_bondInitialHalfDna,
            uint80 B_bondFinalHalfDna,
            uint256 B_troveSize,
            uint256 B_lqtyAmount,
            uint256 B_curveGaugeSlopes
        ) = bondNFT.getBondExtraData(2);
        assertEq(B_bondInitialHalfDna, 0);
        assertEq(B_bondFinalHalfDna, 0);
        assertEq(B_troveSize, 0);
        assertEq(B_lqtyAmount, 0);
        assertEq(B_curveGaugeSlopes, 0);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, MIN_BOND_AMOUNT);

        // Check bonded amount and bond start time are now recorded for B's bond
        (B_bondedLUSD, B_claimedBLUSD, B_bondStartTime,, B_bondStatus) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, MIN_BOND_AMOUNT);
        assertEq(B_claimedBLUSD, 0);
        assertEq(B_bondStartTime, currentTime);
        assertEq(B_bondStatus, uint8(IChickenBondManager.BondStatus.active));

        (B_bondInitialHalfDna, B_bondFinalHalfDna, B_troveSize, B_lqtyAmount, B_curveGaugeSlopes) = bondNFT.getBondExtraData(2);
        assertGt(B_bondInitialHalfDna, 0);
        assertEq(B_bondFinalHalfDna, 0);
        assertEq(B_troveSize, 0);
        assertEq(B_lqtyAmount, 0);
        assertEq(B_curveGaugeSlopes, 0);
    }

    function testFirstCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.totalSupply();

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.totalSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testFirstCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // Get NFT total minted before
        uint256 totalSupplyBefore = bondNFT.totalSupply();

        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Check total minted after has increased by 1
        uint256 totalSupplyAfter = bondNFT.totalSupply();
        assertEq(totalSupplyBefore + 1, totalSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTSupplyByOne() public {
        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Get NFT token supply before
        uint256 tokenSupplyBefore = bondNFT.totalSupply();

        // B creates bond
        createBondForUser(B,  MIN_BOND_AMOUNT);

        // Check NFT token supply after has increased by 1
        uint256 tokenSupplyAfter = bondNFT.totalSupply();
        assertEq(tokenSupplyBefore + 1, tokenSupplyAfter);
    }

    function testCreateBondIncreasesTheBondNFTTotalMintedByOne() public {
        // A creates bond
        createBondForUser(A, MIN_BOND_AMOUNT);

        // Get NFT total minted before
        uint256 totalSupplyBefore = bondNFT.totalSupply();

        // B creates bond
       createBondForUser(B, MIN_BOND_AMOUNT);

        // Check NFT total minted after has increased by 1
        uint256 totalSupplyAfter = bondNFT.totalSupply();
        assertEq(totalSupplyBefore + 1, totalSupplyAfter);
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
        assertEq(bondNFT.totalSupply(),  1);
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
        vm.expectRevert("CBM: Bond minimum amount not reached");
        chickenBondManager.createBond(0);
    }

    function testCreateBondDoesNotChangePermanentBucket() public {
        uint256 bondAmount = 100e18;

        uint256 permanentLUSD_1 = chickenBondManager.getPermanentLUSD();

        // A creates bond
        createBondForUser(A, bondAmount);
        uint256 bondNFT_A = bondNFT.totalSupply();

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
        uint256 B_bondID = bondNFT.totalSupply();

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

    function testChickenOutTransferbLUSDToBonder() public {
        // A, B create bond
        uint256 bondAmount = 171e17 + MIN_BOND_AMOUNT;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalSupply();

        // Get B lusd balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertApproximatelyEqual(B_LUSDBalanceAfter, B_LUSDBalanceBefore + bondAmount, 1e3);
    }

    function testChickenOutDoesNotChangeBondNFTTotalMinted() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        // Since B was the last bonder, his bond ID is the current total minted
        uint256 B_bondID = bondNFT.totalSupply();
        uint256 nftTotalMintedBefore = bondNFT.totalSupply();

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        uint256 nftTotalMintedAfter = bondNFT.totalSupply();

        // Check NFT token minted does not change
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenOutDoesNotBurnBondNFT() public {
        // A, B create bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 B_bondID = createBondForUser(B, bondAmount);

        // Get NFT total supply before
        uint256 totalSupplyBefore = bondNFT.totalSupply();
        assertEq(totalSupplyBefore, 2);

        // Confirm B's NFT balance is 1
        uint256 B_NFTBalanceBefore = bondNFT.balanceOf(B);
        assertEq(B_NFTBalanceBefore, 1);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID, 0);
        vm.stopPrank();

        // Check total supply hasn't decreased
        uint256 totalSupplyAfter = bondNFT.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore);

        // Check B's NFT balance hasn't decreased
        uint256 B_NFTBalanceAfter = bondNFT.balanceOf(B);
        assertEq(B_NFTBalanceAfter, B_NFTBalanceBefore);

        // Check B's still owner of the NFT
        address owner = bondNFT.ownerOf(B_bondID);
        assertEq(owner, B);
    }

    function testChickenOutUpdatesBondData() public {
        uint256 bondAmount = 100e18;
        uint256 expectedStartTime = block.timestamp;
        uint256 bondID = createBondForUser(A, bondAmount);

        (uint256 bdLUSDAmount, uint256 bdClaimedBLUSD, uint256 bdStartTime, uint256 bdEndTime, uint8 bdStatus) = chickenBondManager.getBondData(bondID);
        assertEq(bdStatus, uint8(IChickenBondManager.BondStatus.active));
        assertEq(bdLUSDAmount, bondAmount);
        assertEq(bdClaimedBLUSD, 0);
        assertEq(bdStartTime, expectedStartTime);
        assertEq(bdEndTime, 0);

        (
            uint80 bdInitialHalfDna,
            uint80 bdFinalHalfDna,
            uint256 bdTroveSize,
            uint256 bdLQTYAmount,
            uint256 bdCurveGaugeSlopes
        ) = bondNFT.getBondExtraData(bondID);
        uint80 initialHalfDna = bdInitialHalfDna;
        assertGt(bdInitialHalfDna, 0);
        assertEq(bdFinalHalfDna, 0);
        assertEq(bdTroveSize, 0);
        assertEq(bdLQTYAmount, 0);
        assertEq(bdCurveGaugeSlopes, 0);

        vm.warp(block.timestamp + 600);
        chickenOutForUser(A, bondID);

        (bdLUSDAmount, bdClaimedBLUSD, bdStartTime, bdEndTime, bdStatus) = chickenBondManager.getBondData(bondID);
        assertEq(bdLUSDAmount, bondAmount);
        assertEq(bdClaimedBLUSD, 0);
        assertEq(bdStartTime, expectedStartTime);
        assertEq(bdEndTime, block.timestamp);
        assertEq(bdStatus, uint8(IChickenBondManager.BondStatus.chickenedOut));

        (bdInitialHalfDna, bdFinalHalfDna, bdTroveSize, bdLQTYAmount, bdCurveGaugeSlopes) = bondNFT.getBondExtraData(bondID);
        assertGt(bdInitialHalfDna, 0);
        assertGt(bdFinalHalfDna, 0);
        assertEq(bdInitialHalfDna, initialHalfDna);
        assert(bdFinalHalfDna != bdInitialHalfDna);
        assertEq(bdTroveSize, 0);
        assertEq(bdLQTYAmount, 0);
        assertEq(bdCurveGaugeSlopes, 0);
    }

    function testChickenInRevertsAfterChickenOut() public {
        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        chickenOutForUser(A, bondID);

        vm.expectRevert("CBM: Bond must be active");
        chickenInForUser(A, bondID);
    }

    function testChickenOutRevertsAfterChickenOut() public {
        uint256 bondID = createBondForUser(A, 100e18);
        chickenOutForUser(A, bondID);

        vm.expectRevert("CBM: Bond must be active");
        chickenOutForUser(A, bondID);
    }

    function testChickenOutRevertsWhenCallerIsNotBonder() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

        // A attempts to chicken out B's bond
        vm.startPrank(A);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenOut(B_bondID, 0);
    }

    function testChickenOutDoesNotChangePermanentBucket() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 bondID_A = bondNFT.totalSupply();

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
        uint256 bondID_B = bondNFT.totalSupply();
        createBondForUser(C, bondAmount);
        uint256 bondID_C = bondNFT.totalSupply();

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

        uint256 A_bondID = bondNFT.totalSupply();

        uint256 A_accruedBLUSD = chickenBondManager.calcAccruedBLUSD(A_bondID);
        assertEq(A_accruedBLUSD, 0);
    }

    function testCalcAccruedBLUSDReturnsNonZeroBLUSDForNonZeroInterval(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 bondID_A = bondNFT.totalSupply();

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

        uint256 bondID_B = bondNFT.totalSupply();

        uint256 accruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(bondID_B);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedBLUSD_B = chickenBondManager.calcAccruedBLUSD(bondID_B);
        assertTrue(newAccruedBLUSD_B > accruedBLUSD_B);
    }

    function testCalcBLUSDAccrualReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalSupply();

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
        A_bondID = bondNFT.totalSupply();

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 unusedBondID = bondNFT.totalSupply() + 1;

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

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 A_bondID = bondNFT.totalSupply();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
    }

    function testChickenInTransfersAccruedBLUSDToBonder() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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

    function testChickenInDoesNotChangeTotalMinted() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalSupply();

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 nftTotalMintedBefore = bondNFT.totalSupply();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        uint256 nftTotalMintedAfter = bondNFT.totalSupply();
        assertEq(nftTotalMintedAfter, nftTotalMintedBefore);
    }

    function testChickenInDoesNotBurnBondNFT() public {
        // A creates bond
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        // B creates bond
        uint256 B_bondID = createBondForUser(B, bondAmount);

        // bootstrap period passes
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        // Get NFT total supply before
        uint256 totalSupplyBefore = bondNFT.totalSupply();

        // Get B's NFT balance before
        uint256 B_bondNFTBalanceBefore = bondNFT.balanceOf(B);

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total supply doesn't change
        uint256 totalSupplyAfter = bondNFT.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore);

        // Check B's NFT balance doesn't change
        uint256 B_bondNFTBalanceAfter = bondNFT.balanceOf(B);
        assertEq(B_bondNFTBalanceAfter, B_bondNFTBalanceBefore);

        // Check B's still owner of the NFT
        address owner = bondNFT.ownerOf(B_bondID);
        assertEq(owner, B);
    }

    function testChickenInUpdatesBondData() public {
        uint256 bondAmount = 100e18;
        uint256 expectedStartTime = block.timestamp;
        uint256 bondID = createBondForUser(A, bondAmount);

        (uint256 bdLUSDAmount, uint256 bdClaimedBLUSD, uint256 bdStartTime, uint256 bdEndTime, uint8 bdStatus) = chickenBondManager.getBondData(bondID);
        assertEq(bdLUSDAmount, bondAmount);
        assertEq(bdClaimedBLUSD, 0);
        assertEq(bdStartTime, expectedStartTime);
        assertEq(bdEndTime, 0);
        assertEq(bdStatus, uint8(IChickenBondManager.BondStatus.active));

        (
            uint80 bdInitialHalfDna,
            uint80 bdFinalHalfDna,
            uint256 bdTroveSize,
            uint256 bdLQTYAmount,
            uint256 bdCurveGaugeSlopes
        ) = bondNFT.getBondExtraData(bondID);
        uint80 initialHalfDna = bdInitialHalfDna;
        assertGt(bdInitialHalfDna, 0);
        assertEq(bdFinalHalfDna, 0);
        assertEq(bdTroveSize, 0);
        assertEq(bdLQTYAmount, 0);
        assertEq(bdCurveGaugeSlopes, 0);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        // stack too deep, hardcoding it
        //uint256 accruedBLUSD = chickenBondManager.calcAccruedBLUSD(bondID) / 1e18;
        //console.log(chickenBondManager.calcAccruedBLUSD(bondID), "accrued bLUSD");
        chickenInForUser(A, bondID);

        (bdLUSDAmount, bdClaimedBLUSD, bdStartTime, bdEndTime, bdStatus) = chickenBondManager.getBondData(bondID);
        assertEq(bdLUSDAmount, bondAmount);
        //assertEq(bdClaimedBLUSD, accruedBLUSD);
        assertEq(bdClaimedBLUSD, 18);
        assertEq(bdStartTime, expectedStartTime);
        assertEq(bdEndTime, block.timestamp);
        assertEq(bdStatus, uint8(IChickenBondManager.BondStatus.chickenedIn));

        (bdInitialHalfDna, bdFinalHalfDna, bdTroveSize, bdLQTYAmount, bdCurveGaugeSlopes) = bondNFT.getBondExtraData(bondID);
        assertGt(bdInitialHalfDna, 0);
        assertGt(bdFinalHalfDna, 0);
        assertEq(bdInitialHalfDna, initialHalfDna);
        assert(bdFinalHalfDna != bdInitialHalfDna);
        assertEq(bdTroveSize, 0);
        assertEq(bdLQTYAmount, 0);
        assertEq(bdCurveGaugeSlopes, 0);
    }

    function testChickenInRevertsAfterChickenIn() public {
        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        chickenInForUser(A, bondID);

        vm.expectRevert("CBM: Bond must be active");
        chickenInForUser(A, bondID);
    }

    function testChickenOutRevertsAfterChickenIn() public {
        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        chickenInForUser(A, bondID);

        vm.expectRevert("CBM: Bond must be active");
        chickenOutForUser(A, bondID);
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

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 B_bondID = bondNFT.totalSupply();

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
        uint256 A_bondID = bondNFT.totalSupply();

        // fast forward time
        vm.warp(block.timestamp + 7 days);

        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalSupply();

        uint256 permanentLUSD_1 = chickenBondManager.getPermanentLUSD();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        uint256 permanentLUSD_2 = chickenBondManager.getPermanentLUSD();
        assertGt(permanentLUSD_2, permanentLUSD_1);

        // C creates bond
        createBondForUser(C, bondAmount);
        uint256 C_bondID = bondNFT.totalSupply();

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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();
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

        uint256 A_bondID = bondNFT.totalSupply();

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

        uint256 A_bondID = bondNFT.totalSupply();

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
        deal(address(bLUSDToken), B, 5e18);
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
        deal(address(lusdToken), address(chickenBondManager), _depositAmount);

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

    event AccrualParameterUpdated(uint256);

    function testControllerDoesAdjustWhenAgeOfSingleBondIsAboveTarget(uint256 _interval) public {
        uint256 interval = coerce(
            _interval,
            _calcTimeDeltaWhenControllerWillSampleAverageAgeExceedingTarget(0),
            5200 weeks
        );

        uint256 bondID = createBondForUser(A, 100e18);
        vm.warp(block.timestamp + interval);

        vm.expectEmit(false, false, false, false);
        emit AccrualParameterUpdated(0x1337); // param doesn't matter since we're not checking data
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
        deal(address(lusdToken), A, _calcTotalLUSDAmount(_params));

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

    function testTreasuryChangesAfterCreateBond() public {
        (
            uint256 pendingBeforeCreateBond,
            uint256 acquiredBeforeCreateBond,
            uint256 permanentBeforeCreateBond
        ) = chickenBondManager.getTreasury();
        
        uint256 bondAmount = 100e18;
        createBondForUser(A, bondAmount);

        (
            uint256 pendingAfterCreateBond,
            uint256 acquiredAfterCreateBond,
            uint256 permanentAfterCreateBond
        ) = chickenBondManager.getTreasury();

        assertEq(pendingAfterCreateBond, pendingBeforeCreateBond + bondAmount, "Pending bucket should have increased by the bonded amount");
        assertEq(acquiredAfterCreateBond, acquiredBeforeCreateBond, "Acquired bucket shouldn't have changed");
        assertEq(permanentAfterCreateBond, permanentBeforeCreateBond, "Permanent bucket shouldn't have changed");
    }

    function testTreasuryChangesAfterChickenIn() public {
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);
        uint256 bondIdA = bondNFT.totalSupply();

        createBondForUser(B, bondAmount);
        uint256 bondIdB = bondNFT.totalSupply();

        (
            uint256 pendingBeforeChickenIn,
            uint256 acquiredBeforeChickenIn,
            uint256 permanentBeforeChickenIn
        ) = chickenBondManager.getTreasury();

        // Fast forward 7 days to accrue some bLUSD which increases the Acquired bucket on Chicken in
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        uint256 accruedA = chickenBondManager.calcAccruedBLUSD(bondIdA);

        vm.prank(A);
        chickenBondManager.chickenIn(bondIdA);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        uint256 accruedB = chickenBondManager.calcAccruedBLUSD(bondIdB);

        vm.prank(B);
        chickenBondManager.chickenIn(bondIdB);

        (
            uint256 pendingAfterChickenIn,
            uint256 acquiredAfterChickenIn,
            uint256 permanentAfterChickenIn
        ) = chickenBondManager.getTreasury();

        uint256 bondAmountWithFeeDeducted = bondAmount - _getChickenInFeeForAmount(bondAmount);

        uint256 expectedPending = pendingBeforeChickenIn - bondAmount * 2;
        uint256 expectedAcquired = acquiredBeforeChickenIn + accruedA + accruedB;
        uint256 expectedPermanent = permanentBeforeChickenIn + bondAmountWithFeeDeducted * 2 - accruedA - accruedB;

        assertEq(pendingAfterChickenIn, expectedPending, "Pending bucket should have decreased by the bonded amounts");
        assertEq(acquiredAfterChickenIn, expectedAcquired, "Acquired bucket should have increase by the amount of bLUSD accrued");
        assertEq(permanentAfterChickenIn, expectedPermanent, "Permanent bucket should have increased by bond amount minus fee");
    }

    function testTreasuryChangesAfterChickenOut() public {
        // Fast forward past bootstrap period
        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        uint256 bondAmount = 100e18;

        createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());

        createBondForUser(B, bondAmount);
        uint256 bondIdB = bondNFT.totalSupply();  

        (
            uint256 pendingBeforeChickenOut,
            uint256 acquiredBeforeChickenOut,
            uint256 permanentBeforeChickenOut
        ) = chickenBondManager.getTreasury();

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN());
        vm.prank(B);
        chickenBondManager.chickenOut(bondIdB, 0);

         (
            uint256 pendingAfterChickenOut,
            uint256 acquiredAfterChickenOut,
            uint256 permanentAfterChickenOut
        ) = chickenBondManager.getTreasury();
        
        assertEq(pendingAfterChickenOut, pendingBeforeChickenOut - bondAmount, "Pending bucket should have decreased by the bonded amount");
        assertEq(acquiredAfterChickenOut, acquiredBeforeChickenOut, "Acquired bucket shouldn't have changed");
        assertEq(permanentAfterChickenOut, permanentBeforeChickenOut, "Permanent bucket shouldn't have changed");
    }

    function testTreasuryChangesAfterRedeem() public {
        // Obtain some bLUSD by creating/claiming a bond
        uint256 bondAmount = 100e18;
        uint256 bondId = createBondForUser(A, bondAmount);

        vm.warp(block.timestamp + 300 days);

        uint256 accrued = chickenBondManager.calcAccruedBLUSD(bondId);
        chickenInForUser(A, bondId);

        (
            /* uint256 pendingBeforeRedeem */,
            uint256 acquiredBeforeRedeem,
            uint256 permanentBeforeRedeem
        ) = chickenBondManager.getTreasury();

        vm.warp(block.timestamp + chickenBondManager.BOOTSTRAP_PERIOD_REDEEM());

        // Redeem some bLUSD
        uint256 someBLusd = accrued / 2;
        uint256 lusdRedemptionAmountPlusFee = acquiredBeforeRedeem * someBLusd / bLUSDToken.totalSupply();
        vm.prank(A);
        (uint256 lusdRedemptionAmount,) = chickenBondManager.redeem(someBLusd, 0);

        (
            uint256 pendingAfterRedeem,
            uint256 acquiredAfterRedeem,
            uint256 permanentAfterRedeem
        ) = chickenBondManager.getTreasury();
        
        // emit log_named_decimal_uint("Pending before redeem", pendingBeforeRedeem, 18);
        // emit log_named_decimal_uint("Pending after redeem", pendingAfterRedeem, 18);
        // emit log_named_decimal_uint("Acquired before redeem", acquiredBeforeRedeem, 18);
        // emit log_named_decimal_uint("Acquired after redeem", acquiredAfterRedeem, 18);
        // emit log_named_decimal_uint("Permanent before redeem", permanentBeforeRedeem, 18);
        // emit log_named_decimal_uint("Permanent after redeem", permanentAfterRedeem, 18);
        // emit log_named_decimal_uint("Redeemed bLUSD", someBLusd, 18);
        // emit log_named_decimal_uint("LUSD redemption amount", lusdRedemptionAmount, 18);
        // emit log_named_decimal_uint("LUSD redemption amount + fee", lusdRedemptionAmountPlusFee, 18);

        assertEq(pendingAfterRedeem, 0, "Pending bucket should be empty");

        assertApproximatelyEqual(
            acquiredAfterRedeem,
            acquiredBeforeRedeem - lusdRedemptionAmountPlusFee,
            100,
            "Acquired bucket should have decreased by the redeemed amount of LUSD and the fee"
        );

        assertApproximatelyEqual(
            permanentAfterRedeem,
            permanentBeforeRedeem + lusdRedemptionAmountPlusFee - lusdRedemptionAmount,
            100,
            "Permanent bucket should have increased by the LUSD taken as a redemption fee"
        );
    }

    // --- Counters tests ----

    // CI counter

    function testCICounterIncreasesUponCI() public {
        uint256 bondAmount = 100e18;
        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        uint256 CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 0);

        chickenInForUser(A, A_bondId);
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 1);

        chickenInForUser(B, B_bondId);
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 2);
    }

    function testCICounterDoesntChangeUponCO() public {
        uint256 bondAmount = 100e18;
        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        chickenInForUser(A, A_bondId);
        uint256 CICounter = chickenBondManager.countChickenIn();
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 1);

        chickenOutForUser(B, B_bondId);
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 1);
    }

    function testCICounterDoesntChangeUponBondCreation() public {
        uint256 bondAmount = 100e18;
        uint256 A_bondId = createBondForUser(A, bondAmount);
        createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        chickenInForUser(A, A_bondId);
        uint256 CICounter = chickenBondManager.countChickenIn();
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 1);

        createBondForUser(C, bondAmount);
        CICounter = chickenBondManager.countChickenIn();
        assertEq(CICounter, 1);
    }

    // CO counter

    function testCOCounterIncreasesUponCO() public {
        uint256 bondAmount = 100e18;
        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        uint256 COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 0);

        chickenOutForUser(A, A_bondId);
        COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 1);

        chickenOutForUser(B, B_bondId);
        COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 2);
    }

    function testCOCounterDoesntChangeUponCI() public {
        uint256 bondAmount = 100e18;
        uint256 A_bondId = createBondForUser(A, bondAmount);
        createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        uint256 COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 0);

        chickenInForUser(A, A_bondId);
        COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 0);
    }

     function testCOCounterDoesntChangeUponBondCreation() public {
        uint256 bondAmount = 100e18;
        createBondForUser(A, bondAmount);
        createBondForUser(B, bondAmount);

        vm.warp(block.timestamp + 300 days);

        uint256 COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 0);

        createBondForUser(C, bondAmount);
        COCounter = chickenBondManager.countChickenOut();
        assertEq(COCounter, 0);
    }

    // getOpenBondSCount

    function testOpenBondsCountReturnsCorrectValue() public {

        uint256 bondAmount = 100e18;

        uint256 openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);

        // Create 4 bonds
        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);
        uint256 C_bondId = createBondForUser(C, bondAmount);
        createBondForUser(D, bondAmount);

        vm.warp(block.timestamp + 300 days);

        // Chicken out 2
        chickenOutForUser(A, A_bondId);
        chickenOutForUser(B, B_bondId);

        // Chicken in 1
        chickenInForUser(C, C_bondId);

        //Expect (4 - 2 - 1) = 1 open bonds count
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 1);
    }

    function testBondCreationIncreasesOpenBondsCount() public {
        uint256 bondAmount = 100e18;

        uint256 openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);

        createBondForUser(A, bondAmount);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 1);

        createBondForUser(B, bondAmount);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 2);
    }

    function testCIDecreasesOpenBondsCount() public {
        uint256 bondAmount = 100e18;

        uint256 openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);

        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);

        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 2); 
        
        vm.warp(block.timestamp + 300 days);

        chickenInForUser(A, A_bondId);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 1);
        
        chickenInForUser(B, B_bondId);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);
    }


    function testCODecreasesOpenBondsCount() public {
        uint256 bondAmount = 100e18;

        uint256 openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);

        uint256 A_bondId = createBondForUser(A, bondAmount);
        uint256 B_bondId = createBondForUser(B, bondAmount);

        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 2); 
        
        vm.warp(block.timestamp + 300 days);

        chickenOutForUser(A, A_bondId);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 1);
        
        chickenOutForUser(B, B_bondId);
        openBondsCount = chickenBondManager.getOpenBondCount();
        assertEq(openBondsCount, 0);
    }

    function _createPermitSignature(address owner, uint256 bondAmount, uint256 deadline) internal returns (uint8, bytes32, bytes32) {
        address spender = address(chickenBondManager);
        uint256 nonce = lusdToken.nonces(owner);

        bytes32 permitStructHash = keccak256(
            abi.encode(
                lusdToken.permitTypeHash(),
                owner,
                spender,
                bondAmount,
                nonce,
                deadline
            )
        );

        bytes32 permitDigest = keccak256(
            abi.encodePacked("\x19\x01", lusdToken.domainSeparator(), permitStructHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(accounts.accountsPks(0), permitDigest);

        return (v, r, s);
    }

    function _createBondWithPermit(address owner, uint256 bondAmount, uint256 deadline) internal returns (uint256) {
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(owner, bondAmount, deadline);
        vm.prank(owner);
        chickenBondManager.createBondWithPermit(owner, bondAmount, deadline, v, r, s);

        uint256 bondID = bondNFT.totalSupply();
        return bondID;
    }

    function testCreateBondWithPermit() public {
        address owner = accountsList[0];
        uint256 bondAmount = 100e18;
        uint256 deadline = block.timestamp + 100;

        uint256 activeBondsBefore = chickenBondManager.getOpenBondCount();
        _createBondWithPermit(owner, bondAmount, deadline);
        uint256 activeBondsAfter = chickenBondManager.getOpenBondCount();

        assertEq(activeBondsAfter, activeBondsBefore + 1);
    }

    function testCreateBondWithPermitStillSucceedsAfterSignatureFrontrun() public {
        address owner = accountsList[0];
        uint256 bondAmount = 100e18;
        uint256 deadline = block.timestamp + 100;

        uint256 activeBondsBefore = chickenBondManager.getOpenBondCount();

        // Frontrun the owner's createBondWithPermit txn and use their signature to try and block
        // the createBondWithPermit txn from succeeding
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(owner, bondAmount, deadline);
        address notOwner = accountsList[1];
        assertEq(lusdToken.allowance(owner, address(chickenBondManager)), 0, "Initial allowance should be zero");
        vm.prank(notOwner);
        lusdToken.permit(owner, address(chickenBondManager), bondAmount, deadline, v, r, s);
        assertEq(lusdToken.allowance(owner, address(chickenBondManager)), bondAmount, "Allowance after permit should be bond amount");

        _createBondWithPermit(owner, bondAmount, deadline);
        uint256 activeBondsAfter = chickenBondManager.getOpenBondCount();

        assertEq(activeBondsAfter, activeBondsBefore + 1);
    }

    function testCreateBondWithPermitCanChickenOut() public {
        address owner = accountsList[0];
        uint256 bondAmount = 100e18;
        uint256 deadline = block.timestamp + 100;

        uint256 bondID = _createBondWithPermit(owner, bondAmount, deadline);
        assertEq(chickenBondManager.getOpenBondCount(), 1);

        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        chickenBondManager.chickenOut(bondID, 0);

        assertEq(chickenBondManager.getOpenBondCount(), 0);
    }

    function testCreateBondWithPermitCanChickenIn() public {
        address owner = accountsList[0];
        uint256 bondAmount = 100e18;
        uint256 deadline = block.timestamp + 100;

        uint256 bondID = _createBondWithPermit(owner, bondAmount, deadline);
        assertEq(chickenBondManager.getOpenBondCount(), 1);

        vm.warp(block.timestamp + 30 days);
        // Check bLUSD balance is zero
        uint256 bLUSDBalance = bLUSDToken.balanceOf(owner);
        assertEq(bLUSDBalance, 0);

        vm.prank(owner);
        chickenBondManager.chickenIn(bondID);

        // Check bLUSD balance is not zero
        bLUSDBalance = bLUSDToken.balanceOf(owner);
        assertGt(bLUSDBalance, 0);

        assertEq(chickenBondManager.getOpenBondCount(), 0);
    }
}
