pragma solidity 0.6.11;

// Just a dummy file importing BAMM.sol in order to get Foundry to compile it.
// We then deploy BAMM using deployCode() in MainnetTestSetup.
// We need to do this because of incompatible Solidity versions between LUSDChickenBonds & BAMM.
import "b-protocol/packages/contracts/contracts/B.Protocol/BAMM.sol";
