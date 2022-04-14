
pragma solidity ^0.8.10;

import "./BaseTest.sol";

contract ChickenBondManagerTest is BaseTest {
    uint256 constant SECONDS_IN_ONE_MONTH = 2592000;

    // --- Helpers ---

    function createBondForUser(address _user, uint256 _bondAmount) public returns (uint256) {
        vm.startPrank(_user);
        lusdToken.approve(address(chickenBondManager), _bondAmount);
        chickenBondManager.createBond(_bondAmount);
        vm.stopPrank();

        // bond ID
        return bondNFT.totalMinted();
    }

    function depositLUSDToCurveForUser(address _user, uint256 _lusdDeposit) public {
        tip(address(lusdToken), _user, _lusdDeposit); 
        assertGe(lusdToken.balanceOf(_user), _lusdDeposit);
        vm.startPrank(_user);
        lusdToken.approve(address(curvePool), _lusdDeposit);
        curvePool.add_liquidity([_lusdDeposit, 0], 0);
        vm.stopPrank();
    }

    function _getTaxForAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * chickenBondManager.CHICKEN_IN_AMM_TAX() / 1e18;
    }

    function _getTaxedAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * (1e18 - chickenBondManager.CHICKEN_IN_AMM_TAX()) / 1e18;
    }

    function _calcAccruedSLUSD(uint256 _startTime, uint256 _lusdAmount, uint256 _backingRatio) internal view returns (uint256) {
        uint256 bondSLUSDCap = _lusdAmount * 1e18 / _backingRatio;

        uint256 bondDuration = (block.timestamp - _startTime);

        // TODO: replace with final sLUSD accrual formula. */
        return bondSLUSDCap * bondDuration / (bondDuration + SECONDS_IN_ONE_MONTH);
    }

    // --- Tests ---

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
        createBondForUser(A,  25e18);

        // check backing ratio after has not changed
        uint256 backingRatioAfter = chickenBondManager.calcSystemBackingRatio();
        assertEq(backingRatioAfter, backingRatioBefore);
    }

    function testCreateBondDoesNotChangeBackingRatio() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A, 25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get initial backing ratio
        uint256 backingRatio_1 = chickenBondManager.calcSystemBackingRatio();
        
        // B approves the system for LUSD transfer and creates the bond
        createBondForUser(B,  25e18);

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
       createBondForUser(C,  25e18);

        // Check backing ratio is unchanged by the last bond creation
        uint256 backingRatio_4 = chickenBondManager.calcSystemBackingRatio();
        assertApproximatelyEqual(backingRatio_4, backingRatio_3, 1e3);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensIn() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A,  20e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
       createBondForUser(B,  20e18);

        vm.warp(block.timestamp + 1 days);

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(bondID_A);
        vm.stopPrank();

        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSD, 0);

        // C creates bond
        createBondForUser(C,  25e18);
        
        uint256 bondID_C = bondNFT.totalMinted();
        (, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);

        // assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp);
    }

    function testCreateBondSucceedsAfterAnotherBonderChickensOut() public {
        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A,  25e18);

        uint256 bondID_A = bondNFT.totalMinted();

        // B approves the system for LUSD transfer and creates the bond
        createBondForUser(B,  25e18);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(bondID_A);
        vm.stopPrank();

        uint256 totalPendingLUSD = chickenBondManager.totalPendingLUSD();
        assertGt(totalPendingLUSD, 0);

        // C creates bond
       createBondForUser(C,  25e18);

        vm.warp(block.timestamp + 600);

        uint256 bondID_C = bondNFT.totalMinted();
        (uint256 bondedLUSD_C, uint256 bondStartTime_C) = chickenBondManager.getBondData(bondID_C);
        assertEq(bondedLUSD_C, 25e18);
        assertEq(bondStartTime_C, block.timestamp - 600);
    }

    function testFirstCreateBondIncreasesTotalPendingLUSD(uint) public {
        // Get initial pending LUSD
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        
        // Confirm initial total pending LUSD is 0
        assertTrue(totalPendingLUSDBefore == 0);

        // A approves the system for LUSD transfer and creates the bond
        createBondForUser(A,  25e18);

        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDAfter == 25e18);
    }

    function testCreateBondIncreasesTotalPendingLUSD() public {
        // First, A creates an initial bond
        createBondForUser(A, 25e18);
  
        // B creates the bond
        createBondForUser(B, 10e18);

        vm.stopPrank();
        
        // Check totalPendingLUSD has increased by the correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDAfter == 35e18);
    }

    function testCreateBondReducesLUSDBalanceOfBonder() public {
        // Get A balance before
        uint256 balanceBefore = lusdToken.balanceOf(A);

        // A creates bond
        createBondForUser(A, 10e18);

        // Check A balance has reduced by correct amount
        uint256 balanceAfter = lusdToken.balanceOf(A);
        assertEq(balanceBefore - 10e18, balanceAfter);
    }

    function testCreateBondRecordsBondData() public {
        // A creates bond #1
        createBondForUser(A, 10e18);

        // Confirm bond data for bond #2 is 0
        (uint256 B_bondedLUSD, uint256 B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);

        uint256 currentTime = block.timestamp;

        // B creates bond
        createBondForUser(B, 10e18);

        // Check bonded amount and bond start time are now recorded for B's bond
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(2);
        assertEq(B_bondedLUSD, 10e18);
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
        vm.expectRevert("ERC721: owner query for nonexistent token");
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

    function testCreateBondTransfersLUSDToYearnVault() public {
        // Get Yearn vault balance before
        uint256 yearnVaultBalanceBefore = lusdToken.balanceOf(address(yearnLUSDVault));

        // A creates bond
        createBondForUser(A, 10e18);

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

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

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
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        // Confirm B's bond data is now zero'd
        (B_bondedLUSD, B_bondStartTime) = chickenBondManager.getBondData(B_bondID);
        assertEq(B_bondedLUSD, 0);
        assertEq(B_bondStartTime, 0);
    }

    function testChickenOutTransfersLUSDToBonder() public {
        // A, B create bond
        uint256 bondAmount = 171e17;

        createBondForUser(A, bondAmount);

        createBondForUser(B, bondAmount);

        uint256 B_bondID = bondNFT.totalMinted();

        // Get B lusd balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);
        vm.stopPrank();

        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertApproximatelyEqual(B_LUSDBalanceAfter, B_LUSDBalanceBefore + bondAmount, 1e3);
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
        vm.expectRevert("ERC721: owner query for nonexistent token");
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
        vm.expectRevert("ERC721: owner query for nonexistent token");
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

    // --- calcsLUSD Accrual tests ---

    function testCalcAccruedSLUSDReturns0for0StartTime() public {
        // A, B create bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        uint256 A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSD, 0);
    }

    function testCalcAccruedSLUSDReturnsNonZeroSLUSDForNonZeroInterval(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        uint256 A_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertTrue(A_accruedSLUSD > 0);

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
        
        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
    }

    // TODO: convert to fuzz test
    function testCalcAccruedSLUSDNeverReachesCap(uint _interval) public {
         // --- Test first bond ---
        vm.assume(_interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);

        uint256 A_bondID = bondNFT.totalMinted();

        // Time passes
        vm.warp(block.timestamp + _interval);

        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(A_bondID) < chickenBondManager.calcBondSLUSDCap(A_bondID));

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
        
        // Check accrued sLUSD < sLUSD Cap
        assertTrue(chickenBondManager.calcAccruedSLUSD(B_bondID) < chickenBondManager.calcBondSLUSDCap(B_bondID));
    }

    function testCalcAccruedSLUSDIsMonotonicIncreasingWithTime(uint256 _interval) public {
        // --- Test first bond ---
        vm.assume( _interval > 0 && _interval < 5200 weeks);  // 0 < interval < 100 years

        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        uint accruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(bondID_A);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedSLUSD_A = chickenBondManager.calcAccruedSLUSD(bondID_A);
        assertTrue(newAccruedSLUSD_A > accruedSLUSD_A);
        
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

        uint accruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(bondID_B);
        vm.warp(block.timestamp + _interval);
        uint256 newAccruedSLUSD_B = chickenBondManager.calcAccruedSLUSD(bondID_B);
        assertTrue(newAccruedSLUSD_B > accruedSLUSD_B);
    }

    function testCalcSLUSDAccrualReturns0AfterBonderChickenOut() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check A's accrued SLUSD is > 0
        uint256 A_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertGt(A_accruedSLUSDBefore, 0);

        // A chickens out
        vm.startPrank(A);
        chickenBondManager.chickenOut(A_bondID);
        vm.stopPrank();

        // Check A's accrued SLUSD is 0
        uint256 A_accruedSLUSDAfter = chickenBondManager.calcAccruedSLUSD(A_bondID);
        assertEq(A_accruedSLUSDAfter, 0);

        // A, B create bonds
        createBondForUser(A, bondAmount);
        A_bondID = bondNFT.totalMinted();
        
        createBondForUser(B, bondAmount);
        uint256 B_bondID = bondNFT.totalMinted();

        vm.warp(block.timestamp + 30 days);

        // Check B's accrued sLUSD > 0
        uint256 B_accruedSLUSDBefore = chickenBondManager.calcAccruedSLUSD(B_bondID);
        assertGt(B_accruedSLUSDBefore, 0);

        // B chickens out
        vm.startPrank(B);
        chickenBondManager.chickenOut(B_bondID);

        // Check B's accrued sLUSD == 0
        uint256 B_accruedSLUSDAfter = chickenBondManager.calcAccruedSLUSD(B_bondID);
        assertEq(B_accruedSLUSDAfter, 0);
    }

    function testCalcSLUSDAccrualReturns0ForNonBonder() public {
          // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

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

        tip(address(sLUSDToken), B, 5e18);

        uint256 currentTime = block.timestamp;

       // B creates bond
        createBondForUser(B, bondAmount);

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

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // Get B sLUSD balance before
        uint256 B_sLUSDBalanceBefore = sLUSDToken.balanceOf(B);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get B's accrued sLUSD and confirm it is non-zero
        uint256 B_accruedSLUSD = chickenBondManager.calcAccruedSLUSD(B_bondID);
        
        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's sLUSD balance has increased by correct amount
        uint256 B_sLUSDBalanceAfter = sLUSDToken.balanceOf(B);
        assertEq(B_sLUSDBalanceAfter, B_sLUSDBalanceBefore + B_accruedSLUSD);
    }

    function testChickenInIncreasesBondHolderLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Get B LUSD balance before
        uint256 B_LUSDBalanceBefore = lusdToken.balanceOf(B);
    
        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check B's LUSD balance has increased by correct amount
        uint256 B_LUSDBalanceAfter = lusdToken.balanceOf(B);
        assertGt(B_LUSDBalanceAfter, B_LUSDBalanceBefore);
    }
    
    
    function testChickenInDecreasesTotalPendingLUSDByBondAmount() public {
         // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Get total pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();

        // B chickens in
        vm.startPrank(B);
        chickenBondManager.chickenIn(B_bondID);

        // Check total pending LUSD has increased by correct amount
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertLt(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    function testChickenInIncreasesTotalAcquiredLUSD() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);

        // B creates bond
       createBondForUser(B, bondAmount);
       
        uint256 B_bondID = bondNFT.totalMinted();

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
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
        vm.expectRevert("ERC721: owner query for nonexistent token");
        bondNFT.ownerOf(B_bondID);
    }

    function testChickenInChargesTax() public {
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
        assertEq(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), _getTaxForAmount(bondAmount), "Wrong tax diverted to rewards contract");
        // check accrued amount is reduced by tax
        assertApproximatelyEqual(sLUSDToken.balanceOf(B), _getTaxedAmount(_calcAccruedSLUSD(B_startTime, bondAmount, backingRatio)), 1000, "Wrong tax applied to B");

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // A chickens in
        vm.startPrank(A);
        backingRatio = chickenBondManager.calcSystemBackingRatio();
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check rewards contract has received rewards
        assertEq(lusdToken.balanceOf(address(sLUSDLPRewardsStaking)), 2 * _getTaxForAmount(bondAmount), "Wrong tax diverted to rewards contract");
        // check accrued amount is reduced by tax
        assertApproximatelyEqual(sLUSDToken.balanceOf(A), _getTaxedAmount(_calcAccruedSLUSD(A_startTime, bondAmount, backingRatio)), 1000, "Wrong tax applied to A");
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
        vm.expectRevert("ERC721: owner query for nonexistent token");
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

    // --- redemption tests ---

    function testRedeemDecreasesCallersSLUSDBalance() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
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

       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
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

       createBondForUser(A, bondAmount);
    
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
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

       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
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
        uint256 expectedFractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;
        // Ensure the expected remaining is between 0 and 100%
        assertTrue(expectedFractionRemainingAfterRedemption > 0 && expectedFractionRemainingAfterRedemption < 1e18);

        // A creates bond
        uint256 bondAmount = 10e18;
       
       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertEq(A_sLUSDBalance, 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertGt(A_sLUSDBalance, 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        assertGt(sLUSDBalance, 0);
        sLUSDToken.transfer(B, sLUSDBalance);
        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));
        vm.stopPrank();

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();
        
        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        
        assertGt(sLUSDToRedeem, 0);

        assertTrue(sLUSDToRedeem != 0);
        vm.startPrank(B);
       
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);

        // Check acquired LUSD in Yearn has decreased by correct fraction
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        uint256 expectedAcquiredLUSDInYearnAfter = acquiredLUSDInYearnBefore * expectedFractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLUSDInYearnAfter, expectedAcquiredLUSDInYearnAfter, 1000);
    }

    function testRedeemDecreasesAcquiredLUSDInCurveByCorrectFraction() public {
        uint256 redemptionFraction = 5e17; // 50%
        uint256 percentageFee = chickenBondManager.calcRedemptionFeePercentage();
        uint256 fractionRemainingAfterRedemption = redemptionFraction * (1e18 + percentageFee) / 1e18;

        // A creates bond
        uint256 bondAmount = 10e18;
       
       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);
    
        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
      
        // Check A's sLUSD balance is non-zero
        A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance > 0);

        // A transfers his LUSD to B
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.transfer(B, sLUSDBalance);
        vm.stopPrank();

        assertEq(sLUSDBalance, sLUSDToken.balanceOf(B));
        assertEq(sLUSDToken.totalSupply(), sLUSDToken.balanceOf(B));

        // A shifts some LUSD from SP to Curve
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
       
        // Get acquired LUSD in Curve before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        assertGt(acquiredLUSDInCurveBefore, 0);
       
        // B redeems some sLUSD
        uint256 sLUSDToRedeem = sLUSDBalance * redemptionFraction / 1e18;
        vm.startPrank(B);
        assertEq(sLUSDToRedeem, sLUSDToken.totalSupply() * redemptionFraction / 1e18);
        chickenBondManager.redeem(sLUSDToRedeem);
        vm.stopPrank();

        // Check acquired LUSD in curve after has reduced by correct fraction
        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 expectedAcquiredLUSDInCurveAfter = acquiredLUSDInCurveBefore * fractionRemainingAfterRedemption / 1e18;

        assertApproximatelyEqual(acquiredLUSDInCurveAfter, expectedAcquiredLUSDInCurveAfter, 1000);
    }

    function testRedeemChargesRedemptionFee() public {
        // A creates bond
        uint256 bondAmount = 10e18;
        uint256 ROUNDING_ERROR = 2000;

       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        // Confirm A's sLUSD balance is zero
        uint256 A_sLUSDBalance = sLUSDToken.balanceOf(A);
        assertTrue(A_sLUSDBalance == 0);

        uint256 A_bondID = bondNFT.totalMinted();
        // A chickens in
        vm.startPrank(A);
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
        uint256 backingRatio0 = chickenBondManager.calcSystemBackingRatio();

        //assertEq(chickenBondManager.getTotalAcquiredLUSD(), sLUSDToken.totalSupply());
        assertEq(chickenBondManager.calcRedemptionFeePercentage(), 0);
        // B redeems
        uint256 sLUSDToRedeem = sLUSDBalance / 2;
        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToRedeem);

        uint256 B_LUSDBalanceAfter1 = lusdToken.balanceOf(B);
        uint256 backingRatio1 = chickenBondManager.calcSystemBackingRatio();

        // Check B's LUSD Balance has increased by exactly redemption amount:
        // backing ratio was 1, and redemption fee was still zero
        assertApproximatelyEqual(B_LUSDBalanceAfter1 - B_LUSDBalanceBefore, sLUSDToRedeem, ROUNDING_ERROR);
        assertApproximatelyEqual(backingRatio0, backingRatio1, ROUNDING_ERROR);

        // B redeems again
        chickenBondManager.redeem(sLUSDToRedeem);
        uint256 B_LUSDBalanceAfter2 = lusdToken.balanceOf(B);
        uint256 backingRatio2 = chickenBondManager.calcSystemBackingRatio();
        // Check B's LUSD Balance has increased by less than redemption amount
        // backing ratio was 1, but redemption fee was non zero
        assertNotApproximatelyEqual(B_LUSDBalanceAfter2 - B_LUSDBalanceAfter2, sLUSDToRedeem, ROUNDING_ERROR);
        // Now backing ratio should have increased
        assertNotApproximatelyEqual(backingRatio1, backingRatio2, ROUNDING_ERROR);
    }

    function testRedeemRevertsWhenCallerHasInsufficientSLUSD() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

        uint256 A_bondID = bondNFT.totalMinted();

        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // A transfers some sLUSD to B
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

        // Reverts on transfer rather than burn, since it tries to redeem more than the total SLUSD supply, and therefore tries
        // to withdraw more LUSD than is held by the system
        // TODO: Fix. Seems to revert with no reason string (or not catch it)?
        // vm.expectRevert("ERC20: transfer amount exceeds balance");
        // chickenBondManager.redeem(B_sLUSDBalance + sLUSDToken.totalSupply());
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

        createBondForUser(A, bondAmount);

        // 10 minutes passes
        vm.warp(block.timestamp + 600);

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

    function testShiftLUSDFromSPToCurveRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Attempt to shift 0 LUSD
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.shiftLUSDFromSPToCurve(0);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenCurvePriceLessThan1() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Whale deposits to Curve pool and LUSD spot price drops < 1.0
        depositLUSDToCurveForUser(C, 200_000_000e18); // deposit 200m LUSD
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Attempt to shift 10% of acquired LUSD in Yearn
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn()  / 10;
        assertGt(lusdToShift, 0);
        
        // Try to shift the LUSD
        vm.expectRevert("CBM: Curve spot must be > 1.0 before SP->Curve shift");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
    }

    function testShiftLUSDFromSPToCurveRevertsWhenShiftWouldDropCurvePriceBelow1() public {
        // TODO: Artificially raise Yearn LUSD vault deposit limit to accommodate sufficient LUSD for the test
        vm.startPrank(yearnGovernanceAddress);
        yearnLUSDVault.setDepositLimit(1e27);
        vm.stopPrank();
        
        // A creates bond
        uint256 bondAmount = 500_000_000e18; // 500m 

        tip(address(lusdToken), A, bondAmount);
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 1 year passes
        vm.warp(block.timestamp + 365 days);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Check initial price > 1.0
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // --- First check that the amount to shift *would* drop the curve price below 1.0, by having a whale
        // deposit it, checking Curve price, then withdrawing it again --- ///
       
        uint256 lusdAmount = 200_000_000e18;

        // Whale deposits to Curve pool and LUSD spot price drops < 1.0
        depositLUSDToCurveForUser(C, lusdAmount); // deposit 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        //Whale withdraws their LUSD deposit, and LUSD spot price rises > 1.0 again
        vm.startPrank(C);
        uint256 whaleLPShares = curvePool.balanceOf(C);
        curvePool.remove_liquidity_one_coin(whaleLPShares, 0, 0);
        vm.stopPrank();
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // --- Now, attempt the shift that would drop the price below 1.0 --- 
        vm.expectRevert("CBM: SP->Curve shift must decrease spot price to >= 1.0");
        chickenBondManager.shiftLUSDFromSPToCurve(lusdAmount);
    }

    // CBM system trackers
    function testShiftLUSDFromSPToCurveDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        
        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }
    
    function testShiftLUSDFromSPToCurveDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertGt(totalAcquiredLUSDBefore, 0);

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();

        // TODO: Why does the error margin need to be so large here when shifting from SP -> Curve?
        // It's bigger than a rounding error.
        // NOTE: Relative error seems fairly constant as bond size varies (~5th digit)
        // However, relative error increases/decreases as amount shifted increases/decreases 
        // (4th digit when shifting all SP LUSD, 7th digit when shifting only 1% SP LUSD)
        assertApproximatelyEqual(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 1e15);
    }

    function testShiftLUSDFromSPToCurveDoesntChangeCBMPendingLUSDTracker() public {
        uint256 bondAmount = 25e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

       // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check pending LUSD After has not changed 
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers 
    function testShiftLUSDFromSPToCurveDecreasesCBMAcquiredLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Get acquired LUSD in Yearn before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check acquired LUSD in Yearn has decreased
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter < acquiredLUSDInYearnBefore);
    } 
    
    function testShiftLUSDFromSPToCurveDecreasesCBMLUSDInYearnTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Yearn  
        uint256 lusdInYearnBefore = chickenBondManager.calcYearnLUSDVaultShareValue();

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

        // Check CBM's view of LUSD in Yearn has decreased
        uint256 lusdInYearnAfter = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter < lusdInYearnBefore);
    }

    function testShiftLUSDFromSPToCurveIncreasesCBMLUSDInCurveTracker() public {
        // A creates bond
        uint256 bondAmount = 25e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);

        // Get CBM's view of LUSD in Curve before
        uint256 lusdInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift 10% of LUSD in SP 
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10;
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);

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

    function testShiftLUSDFromCurveToSPRevertsForZeroAmount() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);
    
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Attempt to shift 0 LUSD
        vm.expectRevert("CBM: Amount must be > 0");
        chickenBondManager.shiftLUSDFromCurveToSP(0);
    }

    function testShiftLUSDFromCurveToSPRevertsWhenCurvePriceGreaterThan1() public {
        // A creates bond
        uint256 bondAmount = 10e18;

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);
    
        // Check spot price is > 1.0
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // Attempt to shift 10% of acquired LUSD in Yearn
        lusdToShift = chickenBondManager.getAcquiredLUSDInYearn()  / 10;
        assertGt(lusdToShift, 0);
        
        // Try to shift the LUSD
        vm.expectRevert("CBM: Curve spot must be < 1.0 before Curve->SP shift");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
    }

    function testShiftLUSDFromCurveToSPRevertsWhenShiftWouldRaiseCurvePriceAbove1() public {
        // TODO: Artificially raise Yearn LUSD vault deposit limit to accommodate sufficient LUSD for the test
        vm.startPrank(yearnGovernanceAddress);
        yearnLUSDVault.setDepositLimit(1e27);
        vm.stopPrank();
       
        // A creates bond
        uint256 bondAmount = 500_000_000e18; // 500m 

        tip(address(lusdToken), A, bondAmount);
        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 1 year passes
        vm.warp(block.timestamp + 365 days);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // Put some 3CRV in Curve, so that the subsequent SP->Curve shift can move enough LUSD to Curve without crossing
        // the 1.0 price boundary
        uint256 _3crvDeposit = 300_000_000e18;
        tip(address(_3crvToken), D, _3crvDeposit);
        assertGe(_3crvToken.balanceOf(D), _3crvDeposit);
        vm.startPrank(D);
        _3crvToken.approve(address(curvePool), _3crvDeposit);
        curvePool.add_liquidity([0, _3crvDeposit], 0);
        vm.stopPrank();

        // Put some initial LUSD in Curve from CBM: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = 200_000_000e18; // shift 200m
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        // Check initial price > 1.0
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);

        // First, have a whale deposit to the Curve Pool to make the price < 1.0
        uint256 lusdAmount = 200_000_000e18;
        depositLUSDToCurveForUser(C, lusdAmount); // deposit 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Now, attempt to shift the same amount, which would raise the price back above 1.0, and expect it to fail
        vm.expectRevert("CBM: Curve->SP shift must increase spot price to <= 1.0");
        chickenBondManager.shiftLUSDFromCurveToSP(lusdAmount);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeTotalLUSDInCBM() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);
    
        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Get total LUSD in CBM before
        uint256 CBM_lusdBalanceBefore = lusdToken.balanceOf(address(chickenBondManager));

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);
        
        // Check total LUSD in CBM has not changed
        uint256 CBM_lusdBalanceAfter = lusdToken.balanceOf(address(chickenBondManager));

        assertEq(CBM_lusdBalanceAfter, CBM_lusdBalanceBefore);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMTotalAcquiredLUSDTracker() public {
        // A creates bond
        uint256 bondAmount = 10e18;

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // get CBM's recorded total acquired LUSD before
        uint256 totalAcquiredLUSDBefore = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // check CBM's recorded total acquire LUSD hasn't changed
        uint256 totalAcquiredLUSDAfter = chickenBondManager.getTotalAcquiredLUSD();
        assertApproximatelyEqual(totalAcquiredLUSDAfter, totalAcquiredLUSDBefore, 1e3);
    }

    function testShiftLUSDFromCurveToSPDoesntChangeCBMPendingLUSDTracker() public {// A creates bond
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Get pending LUSD before
        uint256 totalPendingLUSDBefore = chickenBondManager.totalPendingLUSD();
        assertTrue(totalPendingLUSDBefore > 0);

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check pending LUSD After has not changed 
        uint256 totalPendingLUSDAfter = chickenBondManager.totalPendingLUSD();
        assertEq(totalPendingLUSDAfter, totalPendingLUSDBefore);
    }

    // CBM Yearn and Curve trackers
    function testShiftLUSDFromCurveToSPIncreasesCBMAcquiredLUSDInYearnTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);


        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Get acquired LUSD in Yearn Before
        uint256 acquiredLUSDInYearnBefore = chickenBondManager.getAcquiredLUSDInYearn();

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check acquired LUSD in Yearn Increases
        uint256 acquiredLUSDInYearnAfter = chickenBondManager.getAcquiredLUSDInYearn();
        assertTrue(acquiredLUSDInYearnAfter > acquiredLUSDInYearnBefore);
    }

    function testShiftLUSDFromCurveToSPIncreasesCBMLUSDInYearnTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

        createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Get LUSD in Yearn Before
        uint256 lusdInYearnBefore = chickenBondManager.calcYearnLUSDVaultShareValue();

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

        // Check LUSD in Yearn Increases
        uint256 lusdInYearnAfter = chickenBondManager.calcYearnLUSDVaultShareValue();
        assertTrue(lusdInYearnAfter > lusdInYearnBefore);
    }
    
    
    function testShiftLUSDFromCurveToSPDecreasesCBMLUSDInCurveTracker() public {
        uint256 bondAmount = 10e18;

        // B and A create bonds
        createBondForUser(B, bondAmount);

       createBondForUser(A, bondAmount);
        uint256 A_bondID = bondNFT.totalMinted();
       
        // 10 minutes passes
        vm.warp(block.timestamp + 600);
      
        // A chickens in
        vm.startPrank(A);
        chickenBondManager.chickenIn(A_bondID);
        vm.stopPrank();

        // check total acquired LUSD > 0
        uint256 totalAcquiredLUSD = chickenBondManager.getTotalAcquiredLUSD();
        assertTrue(totalAcquiredLUSD > 0);

        // Put some initial LUSD in Curve: shift LUSD from SP to Curve 
        assertEq(chickenBondManager.getAcquiredLUSDInCurve(), 0);
        uint256 lusdToShift = chickenBondManager.getAcquiredLUSDInYearn() / 10; // shift 10% of LUSD in SP
        chickenBondManager.shiftLUSDFromSPToCurve(lusdToShift);
        assertTrue(chickenBondManager.getAcquiredLUSDInCurve() > 0);

        uint256 curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPrice, 1e18);
        // Some user makes large LUSD deposit to Curve, moving Curve spot price below 1.0
        depositLUSDToCurveForUser(C, 2000_000_000e18); // C deposits 200m LUSD
        curveSpotPrice = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPrice, 1e18);

        // Get acquired LUSD in Curve Before
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();

        // Shift LUSD from Curve to SP
        lusdToShift = chickenBondManager.getAcquiredLUSDInCurve() / 10; // shift 10% of LUSD in Curve
        chickenBondManager.shiftLUSDFromCurveToSP(lusdToShift);

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

        assertApproximatelyEqual(lusdBalAfter, fractionalCBMShareValue, 1e3);
    }

    function testCalcYearnLUSDShareValueGivesCorrectAmountAtFirstDepositFullWithdrawal() public {
        // Assume  10 wei < deposit < availableDepositLimit  (For very tiny deposits <10wei, the Yearn vault share calculation can  round to 0).
        // uint256 availableDepositLimit = yearnLUSDVault.availableDepositLimit();
        // vm.assume(_depositAmount < availableDepositLimit && _depositAmount > 10);

        uint _depositAmount = 6013798781155418312;

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

        // Check that the CBM received approximately and at least all of it's share value
        assertGeAndWithinRange(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue, 1e3);
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

        // Artificually withdraw all the share value as CBM  
        uint256 shares = yearnLUSDVault.balanceOf(address(chickenBondManager));
        yearnLUSDVault.withdraw(shares);

        // Check that the CBM received at least all of it's share value
        assertGeAndWithinRange(lusdToken.balanceOf(address(chickenBondManager)), CBMShareLUSDValue, 1e9);
    }
    
    // Test calculated share value does not change over time, ceteris paribus
    function testCalcYearnLUSDShareValueDoesNotChangeOverTimeAllElseEqual() public { 
        uint256 bondAmount = 10e18;
        
        // A creates bond
        createBondForUser(A, bondAmount);

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
        createBondForUser(B, bondAmount);

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
        createBondForUser(A, bondAmount);

        uint256 bondID_A = bondNFT.totalMinted();

        // Get total yTokens 1
        uint256 yTokensYearnLUSD_1 = yearnLUSDVault.totalSupply();
        assertGt(yTokensYearnLUSD_1, 0);

        // Fast forward time
        vm.warp(block.timestamp + 1e6);

        // Check total yTokens 2 == total yTokens 1
        uint256 yTokensYearnLUSD_2 = yearnLUSDVault.totalSupply();
        assertEq(yTokensYearnLUSD_2, yTokensYearnLUSD_1);

        // B creates bond
        createBondForUser(B, bondAmount);

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
        createBondForUser(A, bondAmount);

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
        createBondForUser(B, bondAmount);

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

    // --- Curve getter tests ---

    function testCurveCalcWithdrawOneCoinSucceeds(uint _LUSD3CRVAmount) public {
        uint256 totalLPTokens = curvePool.totalSupply();
        // Total Supply:  92600301889123371838218704
        // Failing input: 926003018891233718382188

        // Seems to revert at >=1% of totalLPTokens. TODO: Why? Does Curve somehow limit withdrawals?

        assertGt(totalLPTokens, 0);

        vm.assume(_LUSD3CRVAmount <= totalLPTokens / 100 && _LUSD3CRVAmount > 0);

        uint256 withdrawableLUSD = curvePool.calc_withdraw_one_coin(_LUSD3CRVAmount * 100, 0);

        assertGt(withdrawableLUSD, 0);

    }

    function testCurveCalcTokenAmountWithdrawalSucceeds(uint256 _lusdAmount) public {
        uint256 totalLUSDinCurve = curvePool.balances(0);
        vm.assume(_lusdAmount < totalLUSDinCurve && _lusdAmount > 1e18);

        bool isDeposit = false;
        uint256 lpTokensToBurn = curvePool.calc_token_amount([_lusdAmount, 0], isDeposit);

        assertGt(lpTokensToBurn, 0);
    }

    function testCurveCalcTokenAmountDepositSucceeds(uint256 _lusdAmount) public {
        vm.assume(_lusdAmount <= 1e27 && _lusdAmount > 1e18);

        bool isDeposit = true;
        uint256 lpTokensReceived = curvePool.calc_token_amount([_lusdAmount, 0], isDeposit);

        assertGt(lpTokensReceived, 0);
    }
}
