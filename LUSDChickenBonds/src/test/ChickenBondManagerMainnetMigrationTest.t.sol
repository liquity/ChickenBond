pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";

contract ChickenBondManagerMainnetMigrationTest is BaseTest, MainnetTestSetup {
    // --- activateMigration ---

    function testMigrationOnlyYearnGovernanceCanCallActivateMigration() public {
        // Create some bonds
        uint256 bondAmount = MIN_BOND_AMOUNT;
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
        uint256 bondAmount = MIN_BOND_AMOUNT;
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
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);
        deal(address(lusdToken), D, 1e24);
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
        chickenBondManager.chickenOut(D_bondID, 0);
        vm.stopPrank();

        // ... and after a chicken-out
        vm.startPrank(yearnGovernanceAddress);
        vm.expectRevert("CBM: Migration must be not be active");
        chickenBondManager.activateMigration();
        vm.stopPrank();
    }

    function testMigrationReducesPermanentBucketsToZero() public {
        // Create some bonds
        uint256 bondAmount = MIN_BOND_AMOUNT;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check permament buckets are > 0
        assertGt(chickenBondManager.getPermanentLUSD(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permament buckets are 0
        assertEq(chickenBondManager.getPermanentLUSD(), 0);
    }


    // --- Post-migration logic ---

    function testPostMigrationTotalPOLCanBeRedeemed() public {
        // Create some bonds
        uint256 bondAmount = 100000e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some funds to Curve
        chickenBondManager.shiftLUSDFromSPToCurve(bondAmount / 5);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check POL is only in B.Protocol and Curve
        uint256 polCurve = chickenBondManager.getOwnedLUSDInCurve();
        uint256 acquiredLUSDInCurveBefore = chickenBondManager.getAcquiredLUSDInCurve();
        //uint256 acquiredYTokensBefore = yearnCurveVault.balanceOf(address(chickenBondManager));
        uint256 acquiredLUSDInSP = chickenBondManager.getAcquiredLUSDInSP();
        uint256 pendingLUSDInSP = chickenBondManager.getPendingLUSD();
        uint256 polSP = chickenBondManager.getOwnedLUSDInSP();
        (,uint256 rawBalSP,) = bammSPVault.getLUSDValue();

        assertGt(acquiredLUSDInCurveBefore, 0, "ac. lusd in curve !> 0 before redeems");
        assertEq(polCurve, acquiredLUSDInCurveBefore, "polCurve != ac. in Curve");
        assertGt(acquiredLUSDInSP, 0, "ac. lusd in SP !>0 before redeems");
        assertGt(pendingLUSDInSP, 0, "pending lusd in SP !>0 before redeems");
        assertGt(polSP, 0, "pol in SP != 0");
        assertApproximatelyEqual(pendingLUSDInSP + acquiredLUSDInSP, rawBalSP, rawBalSP / 1e9, "B.Protocol bal != pending + acquired before redeems");  // Within 1e-9 relative error

        assertGt(bLUSDToken.totalSupply(), 0);

        // bootstrap period passes
        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_REDEEM);

        // B transfers 50% of his bLUSD to C, and redeems
        vm.startPrank(B);
        bLUSDToken.transfer(C, bLUSDToken.balanceOf(B) / 2);
        chickenBondManager.redeem(bLUSDToken.balanceOf(B), 0);
        vm.stopPrank();

        // A redeems
        vm.startPrank(A);
        chickenBondManager.redeem(bLUSDToken.balanceOf(A), 0);
        vm.stopPrank();

        // Final bLUSD holder C redeems
        vm.startPrank(C);
        chickenBondManager.redeem(bLUSDToken.balanceOf(C), 0);
        vm.stopPrank();
        assertEq(bLUSDToken.balanceOf(C), 0, "C bLUSD !=0 after full redeem");

        // Check all bLUSD has been burned
        assertEq(bLUSDToken.totalSupply(), 0, "bLUSD supply != 0 after full redeem");

        polSP = chickenBondManager.getOwnedLUSDInSP();
        assertEq(polSP, 0,"polSP !=0 after full redeem");

        // Check acquired buckets have been emptied
        acquiredLUSDInSP = chickenBondManager.getAcquiredLUSDInSP();
        assertEq(acquiredLUSDInSP, 0, "ac. lusd in SP !=0 after full redeem");

        uint256 acquiredLUSDInCurveAfter = chickenBondManager.getAcquiredLUSDInCurve();
        uint256 acquiredYTokensAfter = yearnCurveVault.balanceOf(address(chickenBondManager));

        // Check that C was able to redeem nearly all of the remaining acquired LUSD in Curve
        assertEq(acquiredLUSDInCurveAfter, 0, "ac. LUSD in curve after full redeem not 0");
        assertEq(acquiredYTokensAfter, 0, "Curve yTokens after full redeem not 0");

        // Check only pending LUSD remains in the SP
        pendingLUSDInSP = chickenBondManager.getPendingLUSD();
        assertGt(pendingLUSDInSP, 0, "pending !> 0 after full redeem");
        rawBalSP = lusdToken.balanceOf(address(bammSPVault));
        assertEq(rawBalSP, 0, "B.AMM LUSD balance should be zero");
        uint256 lusdInBAMMSPVault = chickenBondManager.getLUSDInBAMMSPVault();
        assertEq(pendingLUSDInSP, lusdInBAMMSPVault, "SP bal != pending after full redemption");
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

        deal(address(lusdToken), D, bondAmount);

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

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        _startShiftCountdownAndWarpInsideWindow();

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

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

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

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check permanent buckets are  > 0 before migration
        assertGt(chickenBondManager.getPermanentLUSD(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check permanent buckets are now 0
        assertEq(chickenBondManager.getPermanentLUSD(), 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID);

        // Check permanent buckets are still 0
        assertEq(chickenBondManager.getPermanentLUSD(), 0);
    }

    // - post migration CI doesnt change SP POL

    function testPostMigrationCIDoesntChangeLUSDInSPVault() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check B.Protocol SP vault is > 0
        uint256 previousOwnedLUSDInSP = chickenBondManager.getOwnedLUSDInSP();
        assertGt(previousOwnedLUSDInSP, 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Check B.Protocol SP vault has the same protocol-owned LUSD
        assertEq(chickenBondManager.getOwnedLUSDInSP(), previousOwnedLUSDInSP, "Owned LUSD in SP should be the same after migration");

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID);

        // Check B.Protocol SP vault has the same protocol-owned LUSD
        assertGt(chickenBondManager.getOwnedLUSDInSP(), previousOwnedLUSDInSP, "Owned LUSD in SP should increase after migration and chicken in");
    }

    function testPostMigrationCIIncreasesAcquiredLUSDInSP() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check yearn SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get SP acquired LUSD
        uint256 acquiredLUSDInSPBeforeCI = chickenBondManager.getAcquiredLUSDInSP();
        assertGt(acquiredLUSDInSPBeforeCI, 0);

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID);

       // Check SP acquired LUSD increases after CI
        uint256 acquiredLUSDInSPAfterCI = chickenBondManager.getAcquiredLUSDInSP();
        assertGt(acquiredLUSDInSPAfterCI, acquiredLUSDInSPBeforeCI);
    }

    function testPostMigrationCISendsRefundToBonder() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

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

    function testPostMigrationCIReducebLUSDSPPendingBucketAndBalance() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check B.Protocol SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get SP LUSD balance and buckets
        uint pendingLUSDInSP1 = chickenBondManager.getPendingLUSD();
        uint SPBal1 = lusdToken.balanceOf(address(bammSPVault));
        uint256 lusdInBAMMSPVault1 = chickenBondManager.getLUSDInBAMMSPVault();

        vm.warp(block.timestamp + 10 days);
        // C chickens in
        chickenInForUser(C, C_bondID);

        // Get SP LUSD balance and buckets
        uint pendingLUSDInSP2 = chickenBondManager.getPendingLUSD();
        uint SPBal2 = lusdToken.balanceOf(address(bammSPVault));
        uint256 lusdInBAMMSPVault2 = chickenBondManager.getLUSDInBAMMSPVault();

        // Check pending bucket and balance decreased
        assertGt(pendingLUSDInSP1, 0, "Pending bucket before last chicken in should be greater than zero");
        assertEq(pendingLUSDInSP2, 0, "Pending bucket should be zero");
        assertEq(SPBal1, 0, "Previous B.Protocol balance should be zero");
        assertEq(SPBal2, 0, "B.Protocol balance should be zero");
        // Due to refund on chicken in after migration, LUSD in B.AMM should decrease
        assertLt(lusdInBAMMSPVault2, lusdInBAMMSPVault1, "LUSD in B.AMM should decrease");
    }

    function testPostMigrationCIDoesntSendChickenInFeeToStakingRewards() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

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

    function testPostMigrationCOPullsPendingLUSDFromLUSDSP() public {
        // Create some bonds
        uint256 bondAmount = 100e18;
        uint A_bondID = createBondForUser(A, bondAmount);
        uint B_bondID = createBondForUser(B, bondAmount);
        uint C_bondID = createBondForUser(C, bondAmount);

        // Warp to the end of shifter bootstrap period
        vm.warp(CBMDeploymentTime + BOOTSTRAP_PERIOD_SHIFT);

        // Chicken some bonds in
        chickenInForUser(A, A_bondID);
        chickenInForUser(B, B_bondID);

        _startShiftCountdownAndWarpInsideWindow();

        // shift some LUSD from SP->Curve
        makeCurveSpotPriceAbove1(200_000_000e18);
        shiftFractionFromSPToCurve(10);

        // Check B.Protocol SP vault is > 0
        assertGt(chickenBondManager.getOwnedLUSDInSP(), 0);

        // Yearn activates migration
        vm.startPrank(yearnGovernanceAddress);
        chickenBondManager.activateMigration();
        vm.stopPrank();

        // Get pending and total LUSD in SP before
        uint256 pendingLUSDBeforeCO = chickenBondManager.getPendingLUSD();
        uint256 spBalanceBeforeCO = lusdToken.balanceOf(address(bammSPVault));
        uint256 lusdInBAMMSPVaultBeforeCO = chickenBondManager.getLUSDInBAMMSPVault();

        assertGt(pendingLUSDBeforeCO, 0);
        assertEq(spBalanceBeforeCO, 0, "B.Protocol balance should be zero before chicken out");

        vm.warp(block.timestamp + 10 days);

        // C chickens out
        vm.startPrank(C);
        chickenBondManager.chickenOut(C_bondID, 0);
        vm.stopPrank();

        uint256 pendingLUSDAfterCO = chickenBondManager.getPendingLUSD();
        uint256 spBalanceAfterCO = lusdToken.balanceOf(address(bammSPVault));
        uint256 lusdInBAMMSPVaultAfterCO = chickenBondManager.getLUSDInBAMMSPVault();

        // Check pending LUSD deceased
        assertEq(pendingLUSDAfterCO, 0, "pending didn't decrease");

        // Check B.AMM balance is still zero (everything is deposited into SP)
        assertEq(spBalanceAfterCO, 0, "B.Protocol balance should be zero after chicken out");

        //Check SP balance decreased
        assertLt(lusdInBAMMSPVaultAfterCO, lusdInBAMMSPVaultBeforeCO, "LUSD in B.AMM should decrease");
    }
}
