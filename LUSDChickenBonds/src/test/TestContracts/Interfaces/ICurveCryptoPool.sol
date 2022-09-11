// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../../Interfaces/ICurvePool.sol";

interface ICurveCryptoPool is ICurvePool {
    function price_scale() external view returns (uint256);
    function lp_price() external view returns (uint256);
    function price_oracle() external view returns (uint256);
}
