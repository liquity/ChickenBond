pragma solidity ^0.8.10;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "./TestContracts/TestUtils.sol";
import "../BondNFT.sol";
import "../Interfaces/IBondNFTArtwork.sol";

import "forge-std/console.sol";

contract DummyArtwork is IBondNFTArtwork {
    using Strings for uint256;

    string prefix;

    constructor(string memory _prefix) {
        prefix = _prefix;
    }

    function tokenURI(uint256 _tokenID, IBondNFT.BondExtraData calldata /*_bondExtraData*/) external view returns (string memory) {
        return string(abi.encodePacked(prefix, _tokenID.toString()));
    }
}

contract DummyChickenBondManager {
    BondNFT bondNFT;

    struct BondData {
        uint256 lusdAmount;
        uint256 startTime;
        uint256 endTime;
        uint8 status;
    }

    mapping (uint256 => BondData) public getBondData;

    constructor(BondNFT _bondNFT) {
        bondNFT = _bondNFT;
    }

    function mint(address _bonder) external returns (uint256 bondID) {
        (bondID,) = bondNFT.mint(_bonder, 0);
    }

    function setBondData(uint256 _bondID, BondData calldata _bondData) external {
        getBondData[_bondID] = _bondData;
    }
}

contract BondNFTTest is Test {
    string constant NAME = "name";
    string constant SYMBOL = "symbol";

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function testBondNFTAddressesCanOnlyBeSetOnce() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0), 0);
        bondNFT.setAddresses(address(0x1337));
        assertEq(address(bondNFT.chickenBondManager()), address(0x1337));

        vm.expectRevert("BondNFT: setAddresses() can only be called once");
        bondNFT.setAddresses(address(0xdead));
    }

    function testBondNFTTokenIDsStartAtOne() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0), 0);
        bondNFT.setAddresses(address(this));

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(this), 1);
        bondNFT.mint(address(this), 0);
    }

    function testBondNFTTokenURIRevertsWhenTokenDoesNotExist() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0), 0);
        vm.expectRevert("BondNFT: URI query for nonexistent token");
        bondNFT.tokenURI(1337);
    }

    function testBondNFTTokenURIIsEmptyWhenArtworkIsZero() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0), 0);
        bondNFT.setAddresses(address(this));
        bondNFT.mint(address(this), 0);

        string memory tokenURI = bondNFT.tokenURI(1);
        assertEq(tokenURI, "");
    }

    function testBondNFTDelegatesTokenURIWhenArtworkIsNotZero() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(new DummyArtwork("prefix/")), 0);
        bondNFT.setAddresses(address(this));
        bondNFT.mint(address(this), 0);

        string memory tokenURI = bondNFT.tokenURI(1);
        assertEq(tokenURI, "prefix/1");
    }

    function testBondNFTArtworkCannotBeSetBeforeSettingAddresses() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0), 0);

        vm.expectRevert("BondNFT: setAddresses() must be called first");
        bondNFT.setArtworkAddress(address(0x1337));
    }

    function testBondNFTArtworkCanBeUpgradedExactlyOnce() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0x1337), 0);
        bondNFT.setAddresses(address(this));

        bondNFT.setArtworkAddress(address(0x1337));
        assertEq(address(bondNFT.artwork()), address(0x1337));

        vm.expectRevert("Ownable: caller is not the owner");
        bondNFT.setArtworkAddress(address(0xdead));
    }

    function testBondNFTCannotBeTransferredDuringLockoutPeriod(uint256 lessThanLockout, uint256 moreThanLockout, bool inOut) public {
        uint256 endTime = block.timestamp; // chicken-in/out time
        uint256 lockoutPeriodSeconds = 1 days;

        lessThanLockout = coerce(lessThanLockout, 0, lockoutPeriodSeconds - 1);
        moreThanLockout = coerce(moreThanLockout, lockoutPeriodSeconds, 2 * lockoutPeriodSeconds);

        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0x1337), lockoutPeriodSeconds);
        DummyChickenBondManager chickenBondManager = new DummyChickenBondManager(bondNFT);
        bondNFT.setAddresses(address(chickenBondManager));

        uint256 bondID = chickenBondManager.mint(address(this));
        chickenBondManager.setBondData(
            bondID,
            DummyChickenBondManager.BondData({
                lusdAmount: 1e18, // doesn't matter
                startTime: endTime, // doesn't matter, just use same as endTime
                endTime: endTime,
                status: uint8(
                    inOut
                        ? IChickenBondManager.BondStatus.chickenedIn
                        : IChickenBondManager.BondStatus.chickenedOut
                )
            })
        );

        vm.warp(endTime + lessThanLockout);

        vm.expectRevert("BondNFT: cannot transfer during lockout period");
        bondNFT.transferFrom(address(this), address(0x1337), bondID);

        vm.warp(endTime + moreThanLockout);

        bondNFT.transferFrom(address(this), address(0x1337), bondID);
        assertEq(bondNFT.ownerOf(bondID), address(0x1337));
    }
}
