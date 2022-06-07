pragma solidity ^0.8.10;

import "./TestContracts/proxy.sol";
import "../Proxy/LQTYChickenBondOperationsScript.sol";
import "./TestContracts/DevTestSetup.sol";


contract LQTYChickenBondManagerDevProxyTest is DevTestSetup {
    DSProxy proxyA;
    LQTYChickenBondOperationsScript chickenBondOperationsScript;

    function setUp() public override {
        super.setUp();

        // Create DSProxy factory
        DSProxyFactory dsProxyFactory = new DSProxyFactory();

        // Create DSProxy’s for users
        proxyA = DSProxy(dsProxyFactory.build(A));
        //proxyB = DSProxy(dsProxyFactory.build(B));

        // Deploy DSProxy scripts
        chickenBondOperationsScript = new LQTYChickenBondOperationsScript(chickenBondManager);
    }

    function createBondForProxy(address _user, uint256 _bondAmount) internal returns (uint256) {
        vm.startPrank(_user);
        lqtyToken.approve(address(chickenBondOperationsScript), _bondAmount);
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
        assertGt(bLQTYToken.balanceOf(A), 0, "Should have received some bLQTY");
    }

    function testChickenOut() public {
        uint256 previousBalance = lqtyToken.balanceOf(A);

        // bond
        uint256 bondId = createBondForProxy(A, 10e18);

        // chicken-out
        vm.startPrank(A);
        chickenBondOperationsScript.chickenOut(bondId);
        vm.stopPrank();

        // checks
        assertEq(lqtyToken.balanceOf(A), previousBalance, "LQTY balance doesn't match");
    }

    function testRedeem() public {
        // create bond
        uint256 bondAmount = 10e18;
        uint256 bondId = createBondForProxy(A, bondAmount);

        vm.warp(block.timestamp + 30 days);

        // chicken-in
        uint256 accruedBLQTY = chickenBondManager.calcAccruedBLQTY(bondId);
        uint256 backingRatio = chickenBondManager.calcSystemBackingRatio();
        vm.startPrank(A);
        chickenBondOperationsScript.chickenIn(bondId);
        vm.stopPrank();

        uint256 previousBalance = lqtyToken.balanceOf(A);

        // redeem
        vm.startPrank(A);
        uint256 bLQTYBalance = bLQTYToken.balanceOf(A);
        bLQTYToken.approve(address(chickenBondOperationsScript), bLQTYBalance);
        chickenBondOperationsScript.redeemAndWithdraw(bLQTYBalance / 2);
        vm.stopPrank();

        // checks
        // fraction redeeemed: 1/2; redemption fee: 1/4; 1/2*(1 - 4) = 3/8
        uint256 expectedLQTYBalance = accruedBLQTY * backingRatio / 1e18 * 3/8;
        assertEq(lqtyToken.balanceOf(A) - previousBalance, expectedLQTYBalance, "LQTY balance doesn't match");
    }
}
