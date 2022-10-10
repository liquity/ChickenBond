pragma solidity ^0.8.10;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../ChickenBondManager.sol";

import "forge-std/console.sol";


contract ChickenBondManagerMainnetChickenInAfterDeployment is Test {
    //uint256 constant MAINNET_DEPLOYMENT_BLOCK_NUMBER = 15674057;
    uint256 constant MAINNET_DEPLOYMENT_BLOCK_TIMESTAMP = 1664877851;

    address constant MAINNET_LUSD_TOKEN_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address constant MAINNET_BLUSD_TOKEN_ADDRESS = 0xB9D7DdDca9a4AC480991865EfEf82E01273F79C3;
    address constant MAINNET_CHICKEN_BOND_MANAGER_ADDRESS = 0x57619FE9C539f890b19c61812226F9703ce37137;
    address constant MAINNET_BLUSD_CURVE_GAUGE = 0xdA0DD1798BE66E17d5aB1Dc476302b56689C2DB4;
    address constant DEPLOYMENT_ADDRESS = 0x9B5715C99d3A9db84cAA904f9f442220651436e8;
    address constant LIQUITY_FUNDS_SAFE_ADDRESS = 0xF06016D822943C42e3Cb7FC3a6A3B1889C1045f8;

    ChickenBondManager constant chickenBondManager = ChickenBondManager(MAINNET_CHICKEN_BOND_MANAGER_ADDRESS);
    IERC20 constant lusdToken = IERC20(MAINNET_LUSD_TOKEN_ADDRESS);
    IERC20 constant bLUSDToken = IERC20(MAINNET_BLUSD_TOKEN_ADDRESS);

    uint256 BOOTSTRAP_PERIOD_CHICKEN_IN;

    function pinBlock(uint256 _blockTimestamp) public {
        vm.warp(_blockTimestamp);
        assertEq(block.timestamp, _blockTimestamp);
    }

    function setUp() public {
        pinBlock(MAINNET_DEPLOYMENT_BLOCK_TIMESTAMP);
        BOOTSTRAP_PERIOD_CHICKEN_IN = chickenBondManager.BOOTSTRAP_PERIOD_CHICKEN_IN();
    }

    function testFirstOldOwnerCannotChickenIn() public {
        uint256 bondID = 1;

        vm.warp(block.timestamp + BOOTSTRAP_PERIOD_CHICKEN_IN);

        vm.startPrank(DEPLOYMENT_ADDRESS);
        vm.expectRevert("CBM: Caller must own the bond");
        chickenBondManager.chickenIn(bondID);
        vm.stopPrank();
    }

    function testFirstChickenInDoesNotWorkBeforeBootsrapPeriod() public {
        uint256 bondID = 1;

        (,, uint256 bondStartTime,,) = chickenBondManager.getBondData(bondID);
        vm.warp(bondStartTime + BOOTSTRAP_PERIOD_CHICKEN_IN - 1);

        vm.startPrank(LIQUITY_FUNDS_SAFE_ADDRESS);
        vm.expectRevert("CBM: First chicken in must wait until bootstrap period is over");
        chickenBondManager.chickenIn(bondID);
        vm.stopPrank();
    }

    function testFirstChickenIn() public {
        uint256 bondID = 1;

        (,, uint256 bondStartTime,,) = chickenBondManager.getBondData(bondID);
        vm.warp(bondStartTime + BOOTSTRAP_PERIOD_CHICKEN_IN);

        assertEq(bLUSDToken.balanceOf(LIQUITY_FUNDS_SAFE_ADDRESS), 0, "bLUSD balance should be zero before Chicken In");

        vm.startPrank(LIQUITY_FUNDS_SAFE_ADDRESS);
        chickenBondManager.chickenIn(bondID);
        vm.stopPrank();

        uint256 ownerbLusdBalance = bLUSDToken.balanceOf(LIQUITY_FUNDS_SAFE_ADDRESS);
        uint256 gaugeLusdBalance = lusdToken.balanceOf(MAINNET_BLUSD_CURVE_GAUGE);
        //console.log(ownerbLusdBalance, "ownerbLusdBalance");
        //console.log(gaugeLusdBalance, "gaugeLusdBalance");

        assertApproximatelyEqual(ownerbLusdBalance, 7785e16, 1e16, "bLUSD balance mismatch"); // Accrued ~= 100 * (1-3%) * 15 days / (15 days + 3.69)
        assertGt(gaugeLusdBalance, 0, "Gauge contract should have received funds");
    }

    // internal helpers

    function abs(uint256 x, uint256 y) public pure returns (uint256) {
        return x > y ? x - y : y - x;
    }

    function assertApproximatelyEqual(uint256 _x, uint256 _y, uint256 _margin, string memory _reason) internal {
        uint256 diff = abs(_x, _y);
        assertLe(diff, _margin, _reason);
    }
}
