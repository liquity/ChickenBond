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
        chickenBondOperationsScript = new ChickenBondOperationsScript(
            chickenBondManager,
            lusdToken,
            sLUSDToken,
            curvePool
        );
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
        uint256 bondId = createBondForProxy(A, 10e18);

        assertEq(bondId, 1);
    }

    function testChickenIn() public {
        uint256 bondId = createBondForProxy(A, 10e18);

        vm.warp(block.timestamp + 30 days);

        vm.startPrank(A);
        chickenBondOperationsScript.chickenIn(bondId);
        vm.stopPrank();
    }

    function testChickenOut() public {
        uint256 bondId = createBondForProxy(A, 10e18);

        vm.startPrank(A);
        chickenBondOperationsScript.chickenOut(bondId);
        vm.stopPrank();
    }

    function testRedeem() public {
        createBondForProxy(A, 10e18);

        vm.startPrank(A);
        //chickenBondOperationsScript.redeem(_amount);
        vm.stopPrank();
    }
}
