pragma solidity ^0.8.10;

// Implementation of QuickSort in Solidity strictly for testing purposes (e.g. used in Foundry).
// Don't deploy this! It's not a good idea to sort arrays in EVM. You'll quickly run out of the block gas limit!
abstract contract QuickSort {
    function _setPivot(uint i) internal virtual;
    function _compareWithPivot(uint i) internal view virtual returns (int);
    function _swap(uint a, uint b) internal virtual;

    function _partition(int lo, int hi) internal returns (int p) {
        int i = lo - 1;
        int j = hi + 1;
        
        _setPivot(uint((hi + lo) / 2));

        for (;;) {
            do { ++i; } while (_compareWithPivot(uint(i)) < 0);
            do { --j; } while (_compareWithPivot(uint(j)) > 0);

            if (i >= j) { return j; }

            _swap(uint(i), uint(j));
        }
    }

    function _sort(int lo, int hi) internal {
        if (lo >= 0 && hi >= 0 && lo < hi) {
            int p = _partition(lo, hi);

            _sort(lo, p);
            _sort(p + 1, hi);
        }
    }
}
