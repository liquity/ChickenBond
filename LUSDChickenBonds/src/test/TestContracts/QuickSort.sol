pragma solidity ^0.8.10;

// Dummy contract to get Slither to work
// It expects every build artifact to include "bytecode"
contract QuickSortIsNotAContract {}

// Implementation of QuickSort in Solidity strictly for testing purposes (e.g. used in Foundry).
function _partition(uint[] memory arr, int lo, int hi) pure returns (int p) {
    int i = lo - 1;
    int j = hi + 1;

    uint pivot = arr[uint((hi + lo) / 2)];

    for (;;) {
        do { ++i; } while (arr[uint(i)] < pivot);
        do { --j; } while (arr[uint(j)] > pivot);

        if (i >= j) { return j; }

        (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
    }
}

function _sort(uint[] memory arr, int lo, int hi) pure {
    if (lo >= 0 && hi >= 0 && lo < hi) {
        int p = _partition(arr, lo, hi);

        _sort(arr, lo, p);
        _sort(arr, p + 1, hi);
    }
}

function sort(uint[] memory arr) pure {
    if (arr.length > 0) {
        _sort(arr, 0, int(arr.length - 1));
    }
}
