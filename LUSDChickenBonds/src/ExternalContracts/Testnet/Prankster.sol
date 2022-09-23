// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./Harvester.sol";
import "./Shifter.sol";
import "./Overlord.sol";

contract Prankster is Harvester, Shifter, Overlord {
    struct PranksterParams {
        Target[] yieldTargets;
        address underlingPrototype;
        address curvePoolAddress;
        address lusdTokenAddress;
        address bLUSDTokenAddress;
        address chickenBondManagerAddress;
        address bondNFTAddress;
        address bLUSDCurvePoolAddress;
    }

    constructor(PranksterParams memory params)
        Harvester(params.lusdTokenAddress, params.yieldTargets)
        Shifter(params.chickenBondManagerAddress, params.curvePoolAddress)
        Overlord(OverlordParams({
            prototype: params.underlingPrototype,
            lusdTokenAddress: params.lusdTokenAddress,
            bLUSDTokenAddress: params.bLUSDTokenAddress,
            chickenBondManagerAddress: params.chickenBondManagerAddress,
            bondNFTAddress: params.bondNFTAddress,
            bLUSDCurvePoolAddress: params.bLUSDCurvePoolAddress
        }))
    {}
}
