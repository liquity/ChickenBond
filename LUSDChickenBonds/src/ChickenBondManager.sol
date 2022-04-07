// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./Interfaces/IBondNFT.sol";
import "./console.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/ISLUSDToken.sol";
import "./Interfaces/IYearnVault.sol";
import "./Interfaces/ICurvePool.sol";
import "./Interfaces/IYearnRegistry.sol";

contract ChickenBondManager is Ownable {

    // ChickenBonds contracts
    IBondNFT public bondNFT;

    ISLUSDToken public sLUSDToken;
    ILUSDToken public lusdToken;

    // External contracts
    ICurvePool curvePool;
    IYearnVault yearnLUSDVault;
    IYearnVault yearnCurveVault;
    IYearnRegistry yearnRegistry;

    // --- Data structures ---

    struct BondData {
        uint256 lusdAmount;
        uint256 startTime;
    }

    uint256 public totalPendingLUSD;
    mapping (uint256 => BondData) public idToBondData;

    uint256 constant MAX_UINT256 = type(uint256).max;
    uint256 constant SECONDS_IN_ONE_MONTH = 2592000;
    int128 constant INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL = 0; 

    // --- constructor ---

   constructor
    (
        address _bondNFTAddress, 
        address _lusdTokenAddress, 
        address _curvePoolAddress,
        address _yearnLUSDVaultAddress, 
        address _yearnCurveVaultAddress,
        address _sLUSDTokenAddress,
        address _yearnRegistryAddress
    ) 
        public onlyOwner 
    {
        bondNFT = IBondNFT(_bondNFTAddress);
        lusdToken = ILUSDToken(_lusdTokenAddress);
        sLUSDToken = ISLUSDToken(_sLUSDTokenAddress);
        curvePool = ICurvePool(_curvePoolAddress);
        yearnLUSDVault = IYearnVault(_yearnLUSDVaultAddress);
        yearnCurveVault = IYearnVault(_yearnCurveVaultAddress);
        yearnRegistry = IYearnRegistry(_yearnRegistryAddress);
    
        // TODO: Decide between one-time infinite LUSD approval to Yearn and Curve (lower gas cost per user tx, less secure) 
        // or limited approval at each bonder action (higher gas cost per user tx, more secure)
        lusdToken.approve(address(yearnLUSDVault), MAX_UINT256);
        lusdToken.approve(address(curvePool), MAX_UINT256);
        curvePool.approve(address(yearnCurveVault), MAX_UINT256);

        // Check that the system is hooked up to the correct latest Yearn vaults
        assert(address(yearnLUSDVault) == yearnRegistry.latestVault(address(lusdToken)));
        // TODO: Check mainnet registry for the deployed Yearn Curve vault
        // assert(address(yearnCurveVault) == yearnRegistry.latestVault(address(curvePool)));

        renounceOwnership();
    }

    // --- User-facing functions ---

    function createBond(uint256 _lusdAmount) external {
        _requireNonZeroAmount(_lusdAmount);
        
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

    function chickenOut(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        uint256 bondedLUSD = idToBondData[_bondID].lusdAmount;
       
        delete idToBondData[_bondID];
        totalPendingLUSD -= bondedLUSD;  

        /* In practice, there could be edge cases where the totalPendingLUSD is not fully backed:
        * - Heavy liquidations, and before yield has been converted
        * - Heavy loss-making liquidations, i.e. at <100% CR
        * - SP or Yearn vault hack that drains LUSD
        *
        * TODO: decide how to handle chickenOuts if/when the recorded totalPendingLUSD is not fully backed by actual 
        * LUSD in Yearn / the SP. */

        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
        /* Occasionally (e.g. when the system contains only one bonder) the withdrawable LUSD in Yearn 
        * will be less than the bonded LUSD due to rounding error in the share calculation. Therefore,
        * withdraw the lesser of the two quantities. */
        uint256 lusdToWithdraw = Math.min(bondedLUSD, lusdInYearn); 

        uint256 yTokensToSwapForLUSD = calcYTokensToBurn(yearnLUSDVault, lusdToWithdraw, lusdInYearn);

        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnLUSDVault.withdraw(yTokensToSwapForLUSD);
        uint256 lusdBalanceAfter = lusdToken.balanceOf(address(this));

        uint256 lusdBalanceDelta = lusdBalanceAfter - lusdBalanceBefore;

        /* Transfer the LUSD balance delta resulting from the Yearn withdrawal, rather than the ideal bondedLUSD. 
        * Reasoning: the LUSD balance delta can be slightly lower than the bondedLUSD due to floor division in the 
        * yToken calculation prior to withdrawal. */
        lusdToken.transfer(msg.sender, lusdBalanceDelta);

        bondNFT.burn(_bondID);
    }

    function chickenIn(uint256 _bondID) external {
        _requireCallerOwnsBond(_bondID);

        BondData memory bond = idToBondData[_bondID];
        uint256 lusdInYearn = calcYearnLUSDVaultShareValue(); 
        uint256 backingRatio = _calcSystemBackingRatio(lusdInYearn);
        uint256 accruedSLUSD = _calcAccruedSLUSD(bond, backingRatio);

        delete idToBondData[_bondID];

        // Subtract the bonded amount from the total pending LUSD (and implicitly increase the total acquired LUSD)
        totalPendingLUSD -= bond.lusdAmount;

        /* Get LUSD amounts to acquire and refund. Acquire LUSD in proportion to the system's current backing ratio, 
        * in order to maintain said ratio. */
        uint256 lusdToAcquire = accruedSLUSD * backingRatio / 1e18;
        uint256 lusdToRefund = bond.lusdAmount - lusdToAcquire;

        assert ((lusdToAcquire + lusdToRefund) <= bond.lusdAmount);

        uint256 yTokensToSwapForLUSD = calcYTokensToBurn(yearnLUSDVault, lusdToRefund, lusdInYearn);

         // Pull the refund from Yearn LUSD vault
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));  
        yearnLUSDVault.withdraw(yTokensToSwapForLUSD);
        uint256 lusdBalanceAfter = lusdToken.balanceOf(address(this));

        uint256 lusdBalanceDelta = lusdBalanceAfter - lusdBalanceBefore; 

        /* Transfer the LUSD balance delta resulting from the Yearn withdrawal, rather than the ideal lusdToRefund. 
        * Reasoning: the LUSD balance delta can be slightly lower than the lusdToRefund due to floor division in the 
        * yToken calculation prior to withdrawal. */
        lusdToken.transfer(msg.sender, lusdBalanceDelta);

        sLUSDToken.mint(msg.sender, accruedSLUSD);
        bondNFT.burn(_bondID);
    }

    function redeem(uint256 _sLUSDToRedeem) external {
        _requireNonZeroAmount(_sLUSDToRedeem);
        
        /* TODO: determine whether we should simply leave the fee in the acquired bucket, or add it to a permanent bucket.
        Current approach leaves redemption fees in the acquired bucket. */
        uint256 fractionOfSLUSDToRedeem = _sLUSDToRedeem * 1e18 / sLUSDToken.totalSupply();
        // Calculate redemption fraction to withdraw, given that we leave the fee inside the system
        uint256 fractionOfAcquiredLUSDToWithdraw = fractionOfSLUSDToRedeem * (1e18 - calcRedemptionFeePercentage()) / 1e18;

        // Get the LUSD to withdraw from Yearn, and the corresponding yTokens
        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
      
        uint256 lusdToWithdrawFromYearn = _getAcquiredLUSDInYearn(lusdInYearn) * fractionOfAcquiredLUSDToWithdraw / 1e18;
        uint256 yTokensToWithdrawFromLUSDVault = calcYTokensToBurn(yearnLUSDVault, lusdToWithdrawFromYearn, lusdInYearn);
        
        // Since 100% of the Curve liquidity is "acquired", just get the yTokens directly
        uint256 yTokensToWithdrawFromCurveVault = yearnCurveVault.balanceOf(address(this)) * fractionOfAcquiredLUSDToWithdraw / 1e18;

        // The LUSD and LUSD3CRV deltas from SP/Curve withdrawals are the amounts to send to the redeemer
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));
     
        if (yTokensToWithdrawFromLUSDVault > 0) {yearnLUSDVault.withdraw(yTokensToWithdrawFromLUSDVault);} // obtain LUSD from Yearn
        if (yTokensToWithdrawFromCurveVault > 0) {yearnCurveVault.withdraw(yTokensToWithdrawFromCurveVault);} // obtain LUSD3CRV from Yearn
     
        uint256 LUSD3CRVDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;
        if (LUSD3CRVDelta > 0) {curvePool.remove_liquidity_one_coin(LUSD3CRVDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);} // obtain LUSD from Curve
    
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
    
        _requireNonZeroAmount(lusdBalanceDelta);

        // Burn the redeemed sLUSD
        sLUSDToken.burn(msg.sender, _sLUSDToRedeem);

        // Send the LUSD to the redeemer
        lusdToken.transfer(msg.sender, lusdBalanceDelta);
    }

    function shiftLUSDFromSPToCurve() external {
        // Calculate the LUSD to pull from the Yearn LUSD vault
        uint256 lusdToShift = _calcLUSDToShiftToCurve();
        _requireNonZeroAmount(lusdToShift);

        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
        uint256 yTokensToBurn = calcYTokensToBurn(yearnLUSDVault, lusdToShift, lusdInYearn);

        // Convert yTokens to LUSD
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        yearnLUSDVault.withdraw(yTokensToBurn);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;
    
        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Curve in return for LUSD3CRV-f tokens
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LP tokens to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.add_liquidity([lusdBalanceDelta, 0], 0);
        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // Deposit the received LUSD3CRV-f to Yearn Curve vault
        yearnCurveVault.deposit(LUSD3CRVBalanceDelta);

        // TODO: Require final Curve LUSD spot price >= 1.0
   }

   function shiftLUSDFromCurveToSP() external {
        // Calculate LUSD to pull from Curve
        uint256 lusdToShift = _calcLUSDToShiftToSP();
        _requireNonZeroAmount(lusdToShift);
        
        //Calculate LUSD3CRV-f needed to withdraw LUSD from Curve
        uint256 LUSD3CRVfToBurn = curvePool.calc_token_amount([lusdToShift, 0], false);

        //Calculate yTokens to swap for LUSD3CRV-f 
        uint256 LUSD3CRVfInYearn = calcYearnCurveVaultShareValue();
        uint256 yTokensToBurn = calcYTokensToBurn(yearnCurveVault, LUSD3CRVfToBurn, LUSD3CRVfInYearn);

        // Convert yTokens to LUSD3CRV-f
        uint256 LUSD3CRVBalanceBefore = curvePool.balanceOf(address(this));

        yearnCurveVault.withdraw(yTokensToBurn);
        uint256 LUSD3CRVBalanceDelta = curvePool.balanceOf(address(this)) - LUSD3CRVBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(LUSD3CRVBalanceDelta == LUSD3CRVfToBurn);

        // Withdraw LUSD from Curve
        uint256 lusdBalanceBefore = lusdToken.balanceOf(address(this));
        /* TODO: Determine if we should pass a minimum amount of LUSD to receive here. Seems infeasible to determinine the mininum on-chain from
        * Curve spot price / quantities, which are manipulable. */
        curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL, 0);
        uint256 lusdBalanceDelta = lusdToken.balanceOf(address(this)) - lusdBalanceBefore;

        // Assertion should hold in principle. In practice, there is usually minor rounding error
        // assert(lusdBalanceDelta == lusdToShift);

        // Deposit the received LUSD to Yearn LUSD vault
        yearnLUSDVault.deposit(lusdBalanceDelta);

        // TODO: Require final Curve LUSD spot price <= 1.0
    }

    // --- Helper functions ---

    /* Placeholder functions for calculating LUSD to shift to/from Curve. They currently shift 10% of the acquired LUSD in the source pool
    * to the destination pool.
    * 
    * TODO: replace with logic that calculates the LUSD quantity to shift based on a resulting Curve spot price that does not cross the 
    boundary price of 1. Requires mathematical formula for quantity based on price (i.e. rearrange Curve spot price formula)
    *
    * Simple alternative:  make the outer shift function revert if the resulting LUSD spot price on Curve has crossed the boundary.
    * Advantage: reduces complexity / bug surface area, and moves the burden of a correct LUSD quantity calculation to the front-end.
    */
    function _calcLUSDToShiftToCurve() public returns (uint256) {  
        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
        return  _getAcquiredLUSDInYearn(lusdInYearn) / 10;
    }

    function _calcLUSDToShiftToSP() public returns (uint256) {
        return getAcquiredLUSDInCurve() / 10;
    }

     // TODO: Determine the basis for the redemption fee formula. 5% constant fee is a placeholder.
    function calcRedemptionFeePercentage() public pure returns (uint256) {
        return 5e16;
    }

    // Internal getter for calculating accrued LUSD based on BondData struct
    function _calcAccruedSLUSD(BondData memory _bond, uint256 _backingRatio) internal view returns (uint256) {
        // All bonds have a non-zero creation timestamp, so return accrued sLQTY 0 if the startTime is 0
        if (_bond.startTime == 0) {return 0;}
        uint256 bondSLUSDCap = _calcBondSLUSDCap(_bond.lusdAmount, _backingRatio);

        /* Simple placeholder formula for the sLUSD accrual of the form: ct/(t+a), where "c" is the cap and  
        * "a" is a constant parameter which determines the accrual rate. The current value of a = SECONDS_IN_ONE_MONTH
        * results in an accrued sLUSD equal to 50% of the cap after one month.
        *
        * TODO: replace with final sLUSD accrual formula. */
        uint256 bondDuration = (block.timestamp - _bond.startTime);

        uint256 accruedSLUSD = bondSLUSDCap * bondDuration / (bondDuration + SECONDS_IN_ONE_MONTH);
        assert(accruedSLUSD < bondSLUSDCap);

        return accruedSLUSD;
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
    function _getTotalAcquiredLUSD(uint256 _lusdInYearn) public view returns (uint256) {
        return  _getAcquiredLUSDInYearn(_lusdInYearn) + getAcquiredLUSDInCurve();
    }

    function _getAcquiredLUSDInYearn(uint256 _lusdInYearn) public view returns (uint256) {
        uint256 totalPendingLUSDCached = totalPendingLUSD;

        /* In principle, the acquired LUSD is always the delta between the LUSD deposited to Yearn and the total pending LUSD.
        * When sLUSD supply == 0 (i.e. before the "first" chicken-in), this delta should be 0. However in practice, due to rounding
        * error in Yearn's share calculation the delta can be negative. We assume that a negative delta always corresponds to 0 acquired LUSD.
        *
        * TODO: Determine if this is the only situation whereby the delta can be negative. Potentially enforce some minimum 
        * chicken-in value so that acquired LUSD always more than covers any rounding error in the share value.
        */
        uint256 acquiredLUSDInYearn = _lusdInYearn > totalPendingLUSD ? _lusdInYearn - totalPendingLUSD : 0;
        assert(acquiredLUSDInYearn >= 0);

        return acquiredLUSDInYearn;
    }

    function getAcquiredLUSDInCurve() public view returns (uint256) {
        uint256 lusd3CRVInYearn = calcYearnCurveVaultShareValue();
        uint256 lusdInCurve;

        // Get the LUSD value of the LUSD-3CRV tokens 
        if (lusd3CRVInYearn > 0) {
            lusdInCurve = curvePool.calc_withdraw_one_coin(lusd3CRVInYearn, INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL);
        }

        return lusdInCurve;
    }

    // Calculates the LUSD value of this contract's Yearn LUSD Vault yTokens held by the ChickenBondManager
    function calcYearnLUSDVaultShareValue() public view returns (uint256) {
        uint256 yTokensHeldByCBM = yearnLUSDVault.balanceOf(address(this));
        return yTokensHeldByCBM * yearnLUSDVault.pricePerShare() / 1e18;
    }

    // Calculates the LUSD3CRV value of LUSD Curve Vault yTokens held by the ChickenBondManager
    function calcYearnCurveVaultShareValue() public view returns (uint256) {
        uint256 yTokensHeldByCBM = yearnCurveVault.balanceOf(address(this));
        return yTokensHeldByCBM * yearnCurveVault.pricePerShare() / 1e18;
    }

    function calcYTokensToBurn(IYearnVault _yearnVault, uint256 _wantedTokenAmount, uint256 _tokensInVault) internal view returns (uint256) {
        uint256 yTokensHeld = _yearnVault.balanceOf(address(this));
        uint256 yTokensToBurn = yTokensHeld * _wantedTokenAmount / _tokensInVault;
        return yTokensToBurn;
    }

    function _calcSystemBackingRatio(uint256 _lusdInYearn) public view returns (uint256) {
        uint256 totalSLUSDSupply = sLUSDToken.totalSupply();
        uint256 totalAcquiredLUSD = _getTotalAcquiredLUSD(_lusdInYearn);
    
        /* TODO: Determine how to define the backing ratio when there is 0 sLUSD and 0 totalAcquiredLUSD,
        * i.e. before the first chickenIn. For now, return a backing ratio of 1. Note: Both quantities would be 0
        * also when the sLUSD supply is fully redeemed.
        */
        if (totalSLUSDSupply == 0  && totalAcquiredLUSD == 0) {return 1e18;}
        if (totalSLUSDSupply == 0) {return MAX_UINT256;}

        return  totalAcquiredLUSD * 1e18 / totalSLUSDSupply;
    }

    // Internal getter for calculating the bond sLUSD cap based on bonded amount and backing ratio
    function _calcBondSLUSDCap(uint256 _bondedAmount, uint256 _backingRatio) internal view returns (uint256) {
        // TODO: potentially refactor this -  i.e. have a (1 / backingRatio) function for more precision
        return _bondedAmount * 1e18 / _backingRatio;
    }

    // --- 'require' functions

    function _requireCallerOwnsBond(uint256 _bondID) internal view {
        require(msg.sender == bondNFT.ownerOf(_bondID), "CBM: Caller must own the bond");
    }

    function _requireNonZeroAmount(uint256 _amount) internal pure {
        require(_amount > 0, "CBM: Amount must be > 0");
    }

    // --- External getter convenience functions ---

    function calcAccruedSLUSD(uint256 _bondID) external view returns (uint256) {
        BondData memory bond = idToBondData[_bondID];
        uint lusdInYearn = calcYearnLUSDVaultShareValue();
        return _calcAccruedSLUSD(bond, _calcSystemBackingRatio(lusdInYearn));
    }

    function calcBondSLUSDCap(uint256 _bondID) external view returns (uint256) {
        uint lusdInYearn = calcYearnLUSDVaultShareValue();
        uint256 backingRatio = _calcSystemBackingRatio(lusdInYearn);
       
        BondData memory bond = idToBondData[_bondID];

        return _calcBondSLUSDCap(bond.lusdAmount, backingRatio);
    }

    function getTotalAcquiredLUSD() external view returns (uint256) {
        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
        return _getTotalAcquiredLUSD(lusdInYearn);
    }

    function getAcquiredLUSDInYearn() external view returns (uint256) {
        uint256 lusdInYearn = calcYearnLUSDVaultShareValue();
        return _getAcquiredLUSDInYearn(lusdInYearn);
    }

    function calcSystemBackingRatio() external view returns (uint256) {
        uint lusdInYearn = calcYearnLUSDVaultShareValue();
        return _calcSystemBackingRatio(lusdInYearn);
    }
}