// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/BaseTest.sol";
import "./TestContracts/ChickenBondManagerTest.sol";


contract ChickenBondManagerDevTest is BaseTest, DevTestSetup, ChickenBondManagerTest {}
