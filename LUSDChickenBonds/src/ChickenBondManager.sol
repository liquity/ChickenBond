// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Interfaces/IBondNFT.sol";
import "./console.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ISLUSDToken.sol";
import "./Interfaces/IMockYearnVault.sol";
import "./Interfaces/ICurvePool.sol";

contract ChickenBondManager is Ownable {
    // ChickenBonds contracts
    IBondNFT public bondNFT;

    ISLUSDToken public sLUSDToken;
    ILUSDToken public lusdToken;

    // External contracts
    ICurvePool curvePool;
    IMockYearnVault yearnLUSDVault;
    IMockYearnVault yearnCurveVault;

    // --- Data structures ---

     struct BondData {
        uint256 lusdAmount;
        uint256 startTime;
    }

    uint256 public totalPendingLUSD;
    mapping (uint => BondData) public idToBondData;

    uint256 constant MAX_UINT256 = type(uint256).max;
    uint256 constant SECONDS_IN_ONE_HOUR = 3600;

    // --- constructor ---

   constructor
    (
        address _bondNFTAddress, 
        address _lusdTokenAddress, 
        address _curvePoolAddress,
        address _yearnLUSDVaultAddress, 
        address _yearnCurveVaultAddress,
        address _sLUSDTokenAddress
    ) 
        public onlyOwner 
    {
        bondNFT = IBondNFT(_bondNFTAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        sLUSDToken = ISLUSDToken(_sLUSDTokenAddress);
        curvePool = ICurvePool(_curvePoolAddress);
        yearnLUSDVault = IMockYearnVault(_yearnLUSDVaultAddress);
        yearnCurveVault = IMockYearnVault(_yearnCurveVaultAddress);

        
        // TODO: Decide between one-time infinite LUSD approval to Yearn and Curve (lower gas cost per user tx, less secure) 
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lusdToken.approve(address(yearnLUSDVault), MAX_UINT256);
        lusdToken.approve(address(curvePool), MAX_UINT256);

        renounceOwnership();
    }

    // --- User-facing functions ---

    function createBond(uint256 _lusdAmount) external {
        // Mint the bond NFT to the caller and get the bond ID
        uint256 bondID = bondNFT.mint(msg.sender);

        //Record the user’s bond data: bond_amount and start_time
        BondData memory bondData;
        bondData.lusdAmount = _lusdAmount;
        bondData.startTime = block.timestamp;
        idToBondData[bondID] = bondData;
        
        totalPendingLUSD += _lusdAmount;

        lusdToken.transferFrom(msg.sender, address(this), _lusdAmount);

        // Deposit the LUSD to the Yearn LUSD vault
        yearnLUSDVault.deposit(_lusdAmount);
    } 

    /* NOTE: chickenOut and chickenIn require the caller to pass their correct _bondID. This can be gleaned from their past
    * emitted createBond event.
    * TODO: Decide if we want on-chain functionality for returning a list of a given bonder's NFTs. Increases minting gas cost.
    */

    function chickenOut(uint _bondID) external {
        _requireCallerOwnsBond(_bondID);

        uint bondedLUSD = idToBondData[_bondID].lusdAmount;
        
        totalPendingLUSD -= bondedLUSD;
        delete idToBondData[_bondID];

        uint yTokensToBurn = yearnLUSDVault.calcYTokenToToken(bondedLUSD);
        yearnLUSDVault.withdraw(yTokensToBurn);

        // Send bonded LUSD back to caller and burn their bond NFT
        lusdToken.transfer(msg.sender, bondedLUSD);
        bondNFT.burn(_bondID);
    }

    function chickenIn(uint _bondID) external {
        _requireCallerOwnsBond(_bondID);

        BondData memory bond = idToBondData[_bondID];
        uint accruedLUSD = _calcAccruedSLUSD(bond);

        _requireCapGreaterThanAccruedSLUSD(accruedLUSD, bond.lusdAmount);
    
        delete idToBondData[_bondID];
        totalPendingLUSD -= bond.lusdAmount;
        
        sLUSDToken.mint(msg.sender, accruedLUSD);
        bondNFT.burn(_bondID);
    }

    function redeem(uint _sLUSDToRedeem) external {
        /* TODO: determine whether we should simply leave the fee in the acquired bucket, or add it to a permanent bucket.
        Current approach leaves redemption fees in the acquired bucket. */
        uint fractionOfSLUSDToRedeem = _sLUSDToRedeem * 1e18 / sLUSDToken.totalSupply();
        
        // Calculate redemption fraction to withdraw, given that we leave the fee inside the system
        uint fractionOfAcquiredLUSDToWithdraw = fractionOfSLUSDToRedeem * (1e18 - calcRedemptionFeePercentage()) / 1e18;

        uint yTokensToWithdrawFromLUSDVault = yearnLUSDVault.balanceOf(address(this)) * fractionOfAcquiredLUSDToWithdraw / 1e18;
        uint yTokensToWithdrawFromCurveVault = yearnCurveVault.balanceOf(address(this)) * fractionOfAcquiredLUSDToWithdraw / 1e18;

        // The LUSD and LUSD3CRV deltas from SP/Curve withdrawals are the amounts to send to the redeemer
        uint lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));

        yearnLUSDVault.withdraw(yTokensToWithdrawFromLUSDVault); // obtain LUSD from Yearn
        yearnCurveVault.withdraw(yTokensToWithdrawFromCurveVault); // obtain LUSD3CRV from Yearn

        uint LUSD3CRVDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;
        curvePool.remove_liquidity(LUSD3CRVDelta); // obtain LUSD from Curve

        uint lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Burn the redeemed sLUSD
        sLUSDToken.burn(msg.sender, _sLUSDToRedeem);

        // Send the LUSD to the redeemer
        lusdToken.transfer(msg.sender, lusdBalanceDelta);
    }

    // TODO: Determine the basis for the redemption fee formula. 5% constant fee is a placeholder.
    function calcRedemptionFeePercentage() public pure returns(uint256) {
        return 5e16;
    }

    // --- Helper functions ---

    // External getter for calculating accrued LUSD based on bond ID
    function calcAccruedSLUSD(uint _bondID) external view returns(uint256) {
        BondData memory bond = idToBondData[_bondID];
        return _calcAccruedSLUSD(bond);
    }

    // Internal getter for calculating accrued LUSD based on BondData struct
    function _calcAccruedSLUSD(BondData memory bond) internal view returns (uint256) {
        // All bonds have a non-zero creation timestamp, so return accrued sLQTY 0 if the startTime is 0
        if (bond.startTime == 0) {return 0;}

        /* Simple linear placeholder formula for the sLUSD accrual: 1 bonded LUSD earns 0.01 sLUSD per hour.
        TODO: replace with final sLUSD accrual formula. */
        uint bondDuration = (block.timestamp - bond.startTime);
        return bond.lusdAmount * bondDuration / (SECONDS_IN_ONE_HOUR * 100);
    }

    function getBondData(uint256 _bondID) external view returns (uint256, uint256) {
        return (idToBondData[_bondID].lusdAmount, idToBondData[_bondID].startTime);
    }

    /* Placeholder function that returns a simple total acquired LUSD metric equal to the sum of:
    *
    * Yearn LUSD vault balance
    * plus
    * the LUSD cash-in value of the Curve LP shares in the Yearn Curve vault
    * minus
    * the total pending LUSD.  
    *
    *
    * In practice, the total acquired LUSD calculation will depend on the specifics of how Yearn vaults calculate 
    their balances and incorporate the yield, and whether we implement a toll on chicken-ins (and therefore divert some permanent DEX liquidity) */
    function getTotalAcquiredLUSD() public view returns (uint256) {
        uint yTokenBalanceLUSD = yearnLUSDVault.balanceOf(address(this));
        uint lusdInYearn = yearnLUSDVault.calcYTokenToToken(yTokenBalanceLUSD);
        
        uint yTokenBalanceLUSD3CRV = yearnCurveVault.balanceOf(address(this));
        uint lusd3CRVInYearn = yearnCurveVault.calcYTokenToToken(yTokenBalanceLUSD3CRV);
        uint lusdInCurve = curvePool.calcLUSD3CRVToLUSD(lusd3CRVInYearn);

        return lusdInYearn + lusdInCurve - totalPendingLUSD;
    }

    function calcSystemBackingRatio() public view returns (uint256) {
        uint totalSLUSDSupply = sLUSDToken.totalSupply();
        uint totalAcquiredLUSD = getTotalAcquiredLUSD();

        /* TODO: Determine how to define the backing ratio when there is 0 sLUSD and 0 totalAcquiredLUSD,
        * i.e. before the first chickenIn. For now, return a backing ratio of 1. Note: Both quantities would be 0
        * also when the sLUSD supply is fully redeemed.
        */
        if (totalSLUSDSupply == 0  && totalAcquiredLUSD == 0) {return 1e18;}
        if (totalSLUSDSupply == 0) {return MAX_UINT256;}

        return  totalAcquiredLUSD * 1e18 / totalSLUSDSupply;
    }

    function calcBondCap(uint _bondedAmount) public view returns (uint256) {
        // TODO: potentially refactor this -  i.e. have a (1 / backingRatio) function for more precision
        return _bondedAmount * 1e18 / calcSystemBackingRatio();
    }

    // --- 'require' functions

    function _requireCallerOwnsBond(uint256 _bondID) internal view {
        require(msg.sender == bondNFT.ownerOf(_bondID), "CBM: Caller must own the bond");
    }

    function _requireCapGreaterThanAccruedSLUSD(uint256 _accruedSLUSD, uint _bondedAmount) internal view {
        uint sLUSDCap = calcBondCap(_bondedAmount);
        require(sLUSDCap >= _accruedSLUSD, "CBM: sLUSD cap must be greater than the accrued sLUSD");
    }
}
