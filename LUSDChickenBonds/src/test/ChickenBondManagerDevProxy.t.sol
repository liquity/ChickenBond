pragma solidity ^0.8.10;

import "./TestContracts/proxy.sol";
import "../Proxy/ChickenBondOperationsScript.sol";
import "./TestContracts/DevTestSetup.sol";


contract ChickenBondManagerDevProxyTest is DevTestSetup {
    DSProxy proxyA;
    ChickenBondOperationsScript chickenBondOperationsScript;

    function setUp() public override {
        super.setUp();

        // Create DSProxy factory
        DSProxyFactory dsProxyFactory = new DSProxyFactory();

        // Create DSProxy’s for users
        proxyA = DSProxy(dsProxyFactory.build(A));
        //proxyB = DSProxy(dsProxyFactory.build(B));

        // Deploy DSProxy scripts
        chickenBondOperationsScript = new ChickenBondOperationsScript(chickenBondManager);
    }

    function createBondForProxy(address _user, uint256 _bondAmount) internal returns (uint256) {
        vm.startPrank(_user);
        lusdToken.approve(address(chickenBondOperationsScript), _bondAmount);
        chickenBondOperationsScript.createBond(_bondAmount);
        vm.stopPrank();

        // bond ID
        return bondNFT.totalMinted();
    }

    function testCreateBond() public {
        // bond
        uint256 bondId = createBondForProxy(A, 10e18);

        assertEq(bondId, 1);
    }

    function testChickenIn() public {
        // bond
        uint256 bondId = createBondForProxy(A, 10e18);

        vm.warp(block.timestamp + 30 days);

        // chicken-in
        vm.startPrank(A);
        chickenBondOperationsScript.chickenIn(bondId);
        vm.stopPrank();

        // checks
        assertGt(sLUSDToken.balanceOf(A), 0, "Should have received some sLUSD");
    }

    function testChickenOut() public {
        uint256 previousBalance = lusdToken.balanceOf(A);

        // bond
        uint256 bondId = createBondForProxy(A, 10e18);

        // chicken-out
        vm.startPrank(A);
        chickenBondOperationsScript.chickenOut(bondId);
        vm.stopPrank();

        // checks
        assertEq(lusdToken.balanceOf(A), previousBalance, "LUSD balance doesn't match");
    }

    function testRedeem() public {
        // create bond
        uint256 bondAmount = 10e18;
        uint256 bondId = createBondForProxy(A, bondAmount);

        vm.warp(block.timestamp + 30 days);

        // chicken-in
        uint256 accruedSLUSD = chickenBondManager.calcAccruedSLUSD(bondId);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondOperationsScript.chickenIn(bondId);
        vm.stopPrank();

        uint256 previousBalance = lusdToken.balanceOf(A);

        // redeem
        vm.startPrank(A);
        uint256 sLUSDBalance = sLUSDToken.balanceOf(A);
        sLUSDToken.approve(address(chickenBondOperationsScript), sLUSDBalance);
        chickenBondOperationsScript.redeemAndWithdraw(sLUSDBalance);
        vm.stopPrank();

        // checks
        uint256 expectedLUSDBalance = accruedSLUSD * backingRatio / 1e18;
        assertEq(lusdToken.balanceOf(A) - previousBalance, expectedLUSDBalance, "LUSD balance doesn't match");
    }
}
