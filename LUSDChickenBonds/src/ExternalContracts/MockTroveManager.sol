pragma solidity ^0.8.11;

import "../Interfaces/ITroveManager.sol";


contract MockTroveManager is ITroveManager {
    uint256 private mockTroveDebt;

    function setTroveDebt(uint256 _mockTroveDebt) external {
        mockTroveDebt = _mockTroveDebt;
    }

    function getTroveDebt(address /* _borrower */) external view returns (uint256) {
        return mockTroveDebt;
    }
}
