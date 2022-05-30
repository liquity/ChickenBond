pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";

contract ChickenBondManagerMainnetMigrationTest is BaseTest, MainnetTestSetup {
   
    // --- activateMigration ---

    function testMigrationOnlyYearnGovernanceCanCallActivateMigration() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // Reverts for bLUSD holder
        vm.startPrank(A); 
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Reverts for current bonder
        vm.startPrank(C);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Reverts for random address
        vm.startPrank(D);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();


        // reverts for yearn non-gov addresses
        address YEARN_STRATEGIST = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7;
        address YEARN_GUARDIAN = 0x846e211e8ba920B353FB717631C015cf04061Cc9;
        address YEARN_KEEPER = 0xaaa8334B378A8B6D8D37cFfEF6A755394B4C89DF;

        vm.startPrank(YEARN_STRATEGIST);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        vm.startPrank(YEARN_GUARDIAN);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        vm.startPrank(YEARN_KEEPER);
        vm.expectRevert("CBM: Only Yearn Governance can call");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // succeeds for Yearn governance
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
    }

    function testMigrationSetsMigrationFlagToTrue() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // Check migration flag down
        assertTrue(!chickenBondManager.migration());

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();

        // Check migration flag now raised
        assertTrue(chickenBondManager.migration());
    }

    function testMigrationOnlyCallableOnceByYearnGov() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
        tip(address(lusdToken), D, 1e24);
        uint D_bondID = createBondForUser(D, bondAmount);
    
        vm.warp(block.timestamp + 30 days);
        
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();

        // Yearn tries to call it immediately after...
        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.activateMigration();

        vm.warp(block.timestamp + 30 days);

        //... and later ...
        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        chickenInForUser(C, C_bondID);

        vm.warp(block.timestamp + 30 days);

        // ... and after a chicken-in ...
        vm.startPrank(yearnGovernanceAddress);
        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.activateMigration();
        vm.stopPrank();
 
        vm.startPrank(D);
        chickenBondManager.chickenOut(D_bondID);
        vm.stopPrank();

        // ... and after a chicken-out
        vm.startPrank(yearnGovernanceAddress);
        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.activateMigration();
        vm.stopPrank();
    }

    function testMigrationReducesPermanentBucketsToZero() public {
        // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check permament buckets are > 0
        assertGt(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertGt(chickenBondManager.getPermanentLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permament buckets are 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInSP(), 0);
    }


    function testMigrationReducesYearnSPVaultToZero() public {
         // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check Yearn SP Vault is > 0
        assertGt(chickenBondManager.calcTotalYearnSPVaultShareValue(), 0);
       
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check Yearn SP vault contains 0 LUSD
        assertEq(chickenBondManager.calcTotalYearnSPVaultShareValue(), 0);
    }

    function testMigrationMovesAllLUSDInYearnToLUSDSilo() public {
         // Create some bonds
        uint256 bondAmount = 10e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check Yearn SP Vault is > 0
        uint256 yearnSPLUSD = chickenBondManager.calcTotalYearnSPVaultShareValue();
        assertGt(yearnSPLUSD, 0);

        uint256 siloLUSDBefore = lusdToken.balanceOf(address(lusdSilo));
        assertEq(siloLUSDBefore, 0);
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        uint256 siloLUSDAfter = lusdToken.balanceOf(address(lusdSilo));

        uint256 siloLUSDIncrease = siloLUSDAfter - siloLUSDBefore;

        uint256 relativeDelta = abs(siloLUSDIncrease, yearnSPLUSD) * 1e18 / yearnSPLUSD;

        // Check all Yearn SP LUSD has been moved to Silo, with <1e-9 relative error tolerance
        assertLt(relativeDelta, 1e9);
    }

    // --- Post-migration logic ---

    function testPostMigrationTotalPOLCanBeRedeemedExceptForFinalRedemptionFee() public {
        // Create some bonds
        uint256 bondAmount = 100000e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // shift some funds to Curve
        chickenBondManager.shiftLUSDFromSPToCurve(bondAmount / 5);
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check POL is only in LUSD Silo Vault and Curve
        uint256 polCurve = chickenBondManager.getOwnedLUSDInCurve();
        uint256 acquiredLUSDInCurve = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 polSP = chickenBondManager.getOwnedLUSDInSP();

        uint256 acquiredLUSDInSilo = chickenBondManager.getAcquiredLUSDInSilo();
        uint256 pendingLUSDInSilo = chickenBondManager.getPendingLUSDInSilo();
        uint rawBalSilo = lusdToken.balanceOf(address(lusdSilo));
        
        assertGt(acquiredLUSDInCurve, 0, "ac. lusd in curve !> 0 before redeems");
        assertEq(polCurve, acquiredLUSDInCurve, "polCurve != ac. in Curve");
        assertEq(polSP, 0, "pol in SP != 0");
        assertGt(acquiredLUSDInSilo, 0, "ac. lusd in silo !>0 before redeems");
        assertGt(pendingLUSDInSilo, 0, "pending lusd in silo !>0 before redeems");
        assertApproximatelyEqual(pendingLUSDInSilo + acquiredLUSDInSilo, rawBalSilo, rawBalSilo / 1e9, "silo bal != pending + acquired before redeems");  // Within 1e-9 relative error
        
        assertGt(bLUSDToken.totalSupply(), 0);

        // B transfers 10% of his bLUSD to C
        uint256 C_bLUSD = bLUSDToken.balanceOf(B) / 10;
        assertGt(C_bLUSD, 0);
        vm.startPrank(B);
        bLUSDToken.transfer(C, C_bLUSD);
        vm.stopPrank();

        // All bLUSD holders redeem
        vm.startPrank(A);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A));
        vm.stopPrank();
        assertEq(bLUSDToken.balanceOf(A), 0, "A bLUSD != 0 after redeem");

        vm.startPrank(B);
        chickenBondManager.redeem(bLUSDToken.balanceOf(B));
        vm.stopPrank();
        assertEq(bLUSDToken.balanceOf(B), 0, "B bLUSD != 0 after redeem");

        // Final bLUSD holder C redeems
        vm.startPrank(C);
        chickenBondManager.redeem(bLUSDToken.balanceOf(C));
        vm.stopPrank();
        assertEq(bLUSDToken.balanceOf(C), 0, "C bLUSD !=0 after full redeem");

        // Check all bLUSD has been burned
        assertEq(bLUSDToken.totalSupply(), 0, "bLUSD supply != 0 after full redeem");

        polSP = chickenBondManager.getOwnedLUSDInSP();
        assertEq(polSP, 0,"polSP !=0 after full redeem");

        // Check acquired buckets have been emptied
        acquiredLUSDInSilo = chickenBondManager.getAcquiredLUSDInSilo();
        acquiredLUSDInCurve = chickenBondManager.getAcquiredLUSDInCurve();
        assertEq(acquiredLUSDInSilo, 0, "ac. lusd in silo !=0 after full redeem");
        //TODO: Fails here, as a small remainder (~0.1%) appears to be left in Curve. May be incorrect
        //calculation in Curve acquired LUSD getter, which itself relies on permanent Curve getter.
        assertEq(acquiredLUSDInCurve, 0, "ac. lusd in curve !=0 after full redeem");

        // Check only pending LUSD remains in the Silo
        pendingLUSDInSilo = chickenBondManager.getPendingLUSDInSilo();
        assertGt(pendingLUSDInSilo, 0, "pending !> 0 after full redeem");
        rawBalSilo = lusdToken.balanceOf(address(lusdSilo));
        assertApproximatelyEqual(pendingLUSDInSilo, rawBalSilo, rawBalSilo / 1e9, "silo bal != pending after full redemption");  // Within 1e-9 relative error
    }

    function testPostMigrationCreateBondReverts() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        tip(address(lusdToken), D, bondAmount);
        
        vm.startPrank(D);
        lusdToken.approve(address(chickenBondManager), bondAmount);
        
        vm.expectRevert("CBM: Migration must be not be active"); 
        chickenBondManager.createBond(bondAmount);
    }

    function testPostMigrationShiftSPToCurveReverts() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.shiftLUSDFromSPToCurve(1); 

        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.shiftLUSDFromSPToCurve(1e27); 
    }

    function testPostMigrationShiftCurveToSPReverts() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // Put some LUSD in Curve
        chickenBondManager.shiftLUSDFromSPToCurve(10e18); 

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        assertTrue(chickenBondManager.migration());
        vm.stopPrank();

        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.shiftLUSDFromCurveToSP(1); 

        uint polCurve = chickenBondManager.getOwnedLUSDInCurve();

        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.shiftLUSDFromCurveToSP(polCurve);
    }
 
    function testPostMigrationCIDoesntIncreasePermanentBuckets() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check permanent buckets are  > 0 before migration
        assertGt(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertGt(chickenBondManager.getPermanentLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permanent buckets are now 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInSP(), 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

        // Check permanent buckets are still 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInSP(), 0);
    }

    // - post migration CI doesnt change SP POL

    function testPostMigrationCIDoesntChangeLUSDInSPVault() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check yearn SP vault now has 0 protocol-owned LUSD
        assertEq(chickenBondManager.getOwnedLUSDInSP(), 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

       // Check yearn SP vault still has 0 protocol-owned LUSD
        assertEq(chickenBondManager.getOwnedLUSDInSP(), 0);
    }

    function testPostMigrationCIIncreasesAcquiredLUSDInLUSDSilo() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get Silo acquired LUSD
        uint256 acquiredLUSDInSiloBeforeCI = chickenBondManager.getAcquiredLUSDInSilo();
        assertGt(acquiredLUSDInSiloBeforeCI, 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

       // Check Silo acquired LUSD increases after CI
        uint256 acquiredLUSDInSiloAfterCI = chickenBondManager.getAcquiredLUSDInSilo();
        assertGt(acquiredLUSDInSiloAfterCI, acquiredLUSDInSiloBeforeCI);
    }

    function testPostMigrationCISendsRefundToBonder() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get C LUSD balance 
        uint256 C_lusdBalBeforeCI = lusdToken.balanceOf(C);
        
        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

        // Check C LUSD balance increases
        uint256 C_lusdBalAfterCI = lusdToken.balanceOf(C);
        assertGt(C_lusdBalAfterCI, C_lusdBalBeforeCI);
    }

    function testPostMigrationCIReducebLUSDSiloPendingBucketAndBalance() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get Silo LUSD balance and buckets
        uint pendingLUSDInSilo1 = chickenBondManager.getPendingLUSDInSilo();
        uint rawPending1 = chickenBondManager.totalPendingLUSD();
        uint siloBal1 = lusdToken.balanceOf(address(lusdSilo));
        
        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

        // Get Silo LUSD balance and buckets
        uint pendingLUSDInSilo2 = chickenBondManager.getPendingLUSDInSilo();
        uint rawPending2 = chickenBondManager.totalPendingLUSD();
        uint siloBal2 = lusdToken.balanceOf(address(lusdSilo));

        // Check pending bucket and balance decreased
        assertLt(pendingLUSDInSilo2, pendingLUSDInSilo1);
        assertLt(rawPending2, rawPending1);
        assertLt(siloBal2, siloBal1);
    }

    function testPostMigrationCIDoesntSendChickenInFeeToStakingRewards() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get rewards staking contract LUSD balance before
        uint256 lusdBalanceStakingBeforeCI = lusdToken.balanceOf(address(curveLiquidityGauge));
        assertGt(lusdBalanceStakingBeforeCI, 0); // should be > 0 from previous CIs in normal mode

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

        // Check rewards staking contract lusd balance is the same
        uint256 lusdBalanceStakingAfterCI = lusdToken.balanceOf(address(curveLiquidityGauge));
        assertEq(lusdBalanceStakingAfterCI,lusdBalanceStakingBeforeCI);  
    }

    function testPostMigrationCOPullsPendingLUSDFromLUSDSilo() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get pending and total LUSD in Silo before
        uint256 pendingLUSDBeforeCO = chickenBondManager.getPendingLUSDInSilo();   
        uint256 siloBalanceBeforeCO = lusdToken.balanceOf(address(lusdSilo));

        assertGt(pendingLUSDBeforeCO, 0);
        assertGt(siloBalanceBeforeCO, 0);

        vm.warp(block.timestamp + 10 days);

        // C chickens in
        vm.startPrank(C);
        chickenBondManager.chickenOut(C_bondID); 
        vm.stopPrank();

        uint256 pendingLUSDAfterCO = chickenBondManager.getPendingLUSDInSilo(); 
        uint256 siloBalanceAfterCO = lusdToken.balanceOf(address(lusdSilo));

        // Check pending LUSD deceased
        assertEq(pendingLUSDAfterCO, 0, "pending didn't decrease"); 

        //Check Silo balance decreased
        assertLt(siloBalanceAfterCO, siloBalanceBeforeCO);
    }
}
