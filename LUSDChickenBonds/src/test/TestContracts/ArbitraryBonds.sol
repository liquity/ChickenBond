pragma solidity ^0.8.10;

import "./QuickSort.sol";

struct ArbitraryBondParams {
    uint256 lusdAmount;
    uint256 startTimeDelta;
}

interface ISortedBonds {
    function getParams() external view returns (ArbitraryBondParams[] memory);
}

contract ArbitraryBondsSortedByStartTimeDelta is QuickSort, ISortedBonds {
    ArbitraryBondParams[] internal params;
    int internal pivot;

    constructor(ArbitraryBondParams[] memory _params) {
        if (_params.length > 0) {
            for (uint i = 0; i < _params.length; ++i) {
                params.push(_params[i]);
            }

            _sort(0, int(_params.length - 1));
        }
    }

    function _setPivot(uint i) internal override {
        pivot = int(params[i].startTimeDelta);
    }

    function _compareWithPivot(uint i) internal view override returns (int) {
        return int(params[i].startTimeDelta) - pivot;
    }

    function _swap(uint a, uint b) internal override {
        ArbitraryBondParams memory tmp = params[a];
        params[a] = params[b];
        params[b] = tmp;
    }

    function getParams() external view override returns (ArbitraryBondParams[] memory) {
        return params;
    }
}
