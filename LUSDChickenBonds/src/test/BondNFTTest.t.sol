pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "../BondNFT.sol";
import "../Interfaces/IBondNFTArtwork.sol";

contract DummyArtwork is IBondNFTArtwork {
    using Strings for uint256;

    string prefix;

    constructor(string memory _prefix) {
        prefix = _prefix;
    }

    function tokenURI(uint256 _tokenID) external view returns (string memory) {
        return string(abi.encodePacked(prefix, _tokenID.toString()));
    }
}

contract BondNFTTest is DSTest {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    string constant NAME = "name";
    string constant SYMBOL = "symbol";

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function testBondNFTAddressesCanOnlyBeSetOnce() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0));
        bondNFT.setAddresses(address(0x1337));
        assertEq(bondNFT.chickenBondManagerAddress(), address(0x1337));

        vm.expectRevert("BondNFT: setAddresses() can only be called once");
        bondNFT.setAddresses(address(0xdead));
    }

    function testBondNFTTokenIDsStartAtOne() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0));
        bondNFT.setAddresses(address(this));

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(this), 1);
        bondNFT.mint(address(this));
    }

    function testBondNFTTokenURIRevertsWhenTokenDoesNotExist() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0));
        vm.expectRevert("BondNFT: URI query for nonexistent token");
        bondNFT.tokenURI(1337);
    }

    function testBondNFTTokenURIIsEmptyWhenArtworkIsZero() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0));
        bondNFT.setAddresses(address(this));
        bondNFT.mint(address(this));

        string memory tokenURI = bondNFT.tokenURI(1);
        assertEq(tokenURI, "");
    }

    function testBondNFTDelegatesTokenURIWhenArtworkIsNotZero() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(new DummyArtwork("prefix/")));
        bondNFT.setAddresses(address(this));
        bondNFT.mint(address(this));

        string memory tokenURI = bondNFT.tokenURI(1);
        assertEq(tokenURI, "prefix/1");
    }

    function testBondNFTArtworkCannotBeSetBeforeSettingAddresses() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0));

        vm.expectRevert("BondNFT: setAddresses() must be called first");
        bondNFT.setArtworkAddress(address(0x1337));
    }

    function testBondNFTArtworkCanBeUpgradedExactlyOnce() public {
        BondNFT bondNFT = new BondNFT(NAME, SYMBOL, address(0x1337));
        bondNFT.setAddresses(address(this));

        bondNFT.setArtworkAddress(address(0x1337));
        assertEq(address(bondNFT.artwork()), address(0x1337));

        vm.expectRevert("Ownable: caller is not the owner");
        bondNFT.setArtworkAddress(address(0xdead));
    }
}
