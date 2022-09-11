// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./TestContracts/BaseTest.sol";
import "./TestContracts/MainnetTestSetup.sol";
import "./TestContracts/ChickenBondManagerTest.sol"; 

contract ChickenBondManagerMainnetTest is BaseTest, MainnetTestSetup, ChickenBondManagerTest { }
