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
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);
        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // Reverts for sLUSD holder
        vm.startPrank(A); 
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Reverts for current bonder
        vm.startPrank(C);
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Reverts for random address
        vm.startPrank(D);
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
        chickenBondManager.activateMigration();
        vm.stopPrank();


        // reverts for yearn non-gov addresses
        address YEARN_STRATEGIST = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7;
        address YEARN_GUARDIAN = 0x846e211e8ba920B353FB717631C015cf04061Cc9;
        address YEARN_KEEPER = 0xaaa8334B378A8B6D8D37cFfEF6A755394B4C89DF;

        vm.startPrank(YEARN_STRATEGIST);
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        vm.startPrank(YEARN_GUARDIAN);
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
        chickenBondManager.activateMigration();
        vm.stopPrank();

        vm.startPrank(YEARN_KEEPER);
        vm.expectRevert("CBM: Only Yearn Governance can activate migration");
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
        uint C_bondID = createBondForUser(C, bondAmount);
    
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
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check permament buckets are > 0
        assertGt(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertGt(chickenBondManager.getPermanentLUSDInYearn(), 0);
        assertGt(chickenBondManager.yTokensPermanentCurveVault(), 0);
        assertGt(chickenBondManager.yTokensPermanentLUSDVault(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permament buckets are 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInYearn(), 0);
        assertEq(chickenBondManager.yTokensPermanentCurveVault(), 0);
        assertEq(chickenBondManager.yTokensPermanentLUSDVault(), 0);
    }


    function testMigrationReducesYearnSPVaultToZero() public {
         // Create some bonds
        uint256 bondAmount = 10e18;
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

        // Check Yearn SP Vault is > 0
        assertGt(chickenBondManager.calcTotalYearnLUSDVaultShareValue(), 0);
       
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check Yearn SP vault contains 0 LUSD
        assertEq(chickenBondManager.calcTotalYearnLUSDVaultShareValue(), 0);
    }

    function testMigrationMovesAllLUSDInYearnToCurve() public {
         // Create some bonds
        uint256 bondAmount = 10e18;
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

        // Check Yearn SP Vault is > 0
        uint256 yearnSPLUSD = chickenBondManager.calcTotalYearnLUSDVaultShareValue();
        assertGt(yearnSPLUSD, 0);

        uint256 yearnCurveLUSD3CRVBefore = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDBefore = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVBefore, 0);
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        uint256 yearnCurveLUSD3CRVAfter = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDAfter = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVAfter, 0);

        uint256 curveLUSDIncrease = curveLUSDAfter - curveLUSDBefore;

        uint256 relativeDelta = abs(curveLUSDIncrease, yearnSPLUSD) * 1e18 / yearnSPLUSD;

        console.log(curveLUSDIncrease, "curveLUSDIncrease");
        console.log(yearnSPLUSD, "yearnSPLUSD");
        console.log(relativeDelta, "relative Delta");
        console.log(1e14, "1e14");

        // Check all Yearn SP LUSD has been moved to Curve, with <0.1% relative error tolerance
        assertLt(relativeDelta, 1e15);
    }

    function testMigrationSucceedsWhenMoveCrossesCurvePriceBoundary() public {
        // Artificially raise Yearn deposit limit
        vm.startPrank(yearnGovernanceAddress);
        yearnLUSDVault.setDepositLimit(1e27);
        vm.stopPrank();
        
        // Create some bonds
        uint256 bondAmount = 100e24;
        tip(address(lusdToken), A, 100e24);
        tip(address(lusdToken), B, 100e24);
        tip(address(lusdToken), C, 100e24);
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        makeCurveSpotPriceAbove1(100_000_000e18);

        // shift small amount  (1 million'th) of LUSD from SP->Curve
        shiftFractionFromSPToCurve(1000000);
        uint256 curveSpotPriceBeforeMigration = curvePool.get_dy_underlying(0, 1, 1e18);
        assertGt(curveSpotPriceBeforeMigration, 1e18);

        // Check Yearn SP Vault is > 0
        uint256 yearnSPLUSD = chickenBondManager.calcTotalYearnLUSDVaultShareValue();

        uint256 yearnCurveLUSD3CRVBefore = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDBefore = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVBefore, 0);
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        uint256 yearnCurveLUSD3CRVAfter = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDAfter = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVAfter, 0);

        uint256 curveLUSDIncrease = curveLUSDAfter - curveLUSDBefore;
    
        uint256 relativeDelta = abs(curveLUSDIncrease, yearnSPLUSD) * 1e18 / yearnSPLUSD;

        console.log(curveLUSDIncrease, "curveLUSDIncrease");
        console.log(yearnSPLUSD, "yearnSPLUSD");

        // Check all Yearn SP LUSD has been moved to Curve, with <0.1% relative error tolerance
        assertLt(relativeDelta, 1e15);

        // Check curve spot has crossed boundary due to migration, and price is less than 1
        uint256 curveSpotPriceAfterMigration = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPriceAfterMigration, 1e18);
    }

    function testMigrationSucceedsWithInitialCurvePriceBelow1() public {
         // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 

        makeCurveSpotPriceAbove1(200_000_000e18);
        // shift small amount  (1 million'th) of LUSD from SP->Curve
        shiftFractionFromSPToCurve(1000000);
        makeCurveSpotPriceBelow1(200_000_000e18);

        uint256 curveSpotPriceBeforeMigration = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPriceBeforeMigration, 1e18);

        // Check Yearn SP Vault is > 0
        uint256 yearnSPLUSD = chickenBondManager.calcTotalYearnLUSDVaultShareValue();

        uint256 yearnCurveLUSD3CRVBefore = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDBefore = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVBefore, 0);
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        uint256 yearnCurveLUSD3CRVAfter = chickenBondManager.calcTotalYearnCurveVaultShareValue();
        uint256 curveLUSDAfter = curvePool.calc_withdraw_one_coin(yearnCurveLUSD3CRVAfter, 0);

        uint256 curveLUSDIncrease = curveLUSDAfter - curveLUSDBefore;
    
        uint256 relativeDelta = abs(curveLUSDIncrease, yearnSPLUSD) * 1e18 / yearnSPLUSD;


        // Check all Yearn SP LUSD has been moved to Curve, with <0.1% relative error tolerance
        assertLt(relativeDelta, 1e15);

        // Check curve spot has *decreased* further below 1
        uint256 curveSpotPriceAfterMigration = curvePool.get_dy_underlying(0, 1, 1e18);
        assertLt(curveSpotPriceAfterMigration, 1e18);
        assertLt(curveSpotPriceAfterMigration, curveSpotPriceBeforeMigration);
    }

    // --- Post-migration logic ---

    function testPostMigrationTotalPOLCanBeRedeemedExceptForFinalRedemptionFee() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check POL is only in Curve Vault
        uint256 polCurve = chickenBondManager.getOwnedLUSDInCurve();
        uint256 acquiredCurve = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 polSP = chickenBondManager.getOwnedLUSDInSP();
        assertGt(acquiredCurve, 0);
        assertEq(polCurve, acquiredCurve);
        assertEq(polSP, 0);

        assertGt(sLUSDToken.totalSupply(), 0);

        // B transfers 10% of his sLUSD to C
        uint256 C_sLUSD = sLUSDToken.balanceOf(B) / 10;
        assertGt(C_sLUSD, 0);
        vm.startPrank(B);
        sLUSDToken.transfer(C, C_sLUSD);
        vm.stopPrank();

        // All sLUSD holders redeem
        vm.startPrank(A);
        chickenBondManager.redeem(sLUSDToken.balanceOf(A));
        vm.stopPrank();
        assertEq(sLUSDToken.balanceOf(A), 0);

        vm.startPrank(B);
        chickenBondManager.redeem(sLUSDToken.balanceOf(B));
        vm.stopPrank();
        assertEq(sLUSDToken.balanceOf(B), 0);


        uint256 curveAcquiredLUSDBeforeLastRedeem = chickenBondManager.getAcquiredLUSDInCurve();
        assertGt(curveAcquiredLUSDBeforeLastRedeem, 0);
        uint256 C_expectedRedemptionFee = curveAcquiredLUSDBeforeLastRedeem * chickenBondManager.calcRedemptionFeePercentage() / 1e18;
        assertGt(C_expectedRedemptionFee, 0);

        vm.startPrank(C);
        chickenBondManager.redeem(sLUSDToken.balanceOf(C));
        vm.stopPrank();
        assertEq(sLUSDToken.balanceOf(C), 0);

        // Check all sLUSD has been burned
        assertEq(sLUSDToken.totalSupply(), 0, "slUSD supply != 0");

        // Check only remaining LUSD in acquired bucket is the fee left over from the final redemption
        uint256 acquiredLUSDInCurve = chickenBondManager.getAcquiredLUSDInCurve();
        console.log(acquiredLUSDInCurve, "acquiredLUSDInCurve");
        console.log(C_expectedRedemptionFee, "C_expectedRedemptionFee");

        uint tolerance = C_expectedRedemptionFee / 1000; // 0.1% relative error tolerance
        assertApproximatelyEqual(acquiredLUSDInCurve, C_expectedRedemptionFee, tolerance);

        polSP = chickenBondManager.getOwnedLUSDInSP();
        assertEq(polSP, 0);
    }

    function testPostMigrationCreateBondReverts() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
    
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
        uint C_bondID = createBondForUser(C, bondAmount);
    
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
        uint C_bondID = createBondForUser(C, bondAmount);
    
        vm.warp(block.timestamp + 30 days);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID); 
     
        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
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
        assertGt(chickenBondManager.getPermanentLUSDInYearn(), 0);
        assertGt(chickenBondManager.yTokensPermanentCurveVault(), 0);
        assertGt(chickenBondManager.yTokensPermanentLUSDVault(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permanent buckets are now 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInYearn(), 0);
        assertEq(chickenBondManager.yTokensPermanentCurveVault(), 0);
        assertEq(chickenBondManager.yTokensPermanentLUSDVault(), 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID); 

        // Check permanent buckets are still 0
        assertEq(chickenBondManager.getPermanentLUSDInCurve(), 0);
        assertEq(chickenBondManager.getPermanentLUSDInYearn(), 0);
        assertEq(chickenBondManager.yTokensPermanentCurveVault(), 0);
        assertEq(chickenBondManager.yTokensPermanentLUSDVault(), 0);  
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

    // Tests TODO:
    // - post-migration CI increases Curve acquired
    // - post-migration CI refunds surplus
    // - post-migration CI doesn't charge a tax
    // - post-migration CO pulls funds from Curve acquired
}