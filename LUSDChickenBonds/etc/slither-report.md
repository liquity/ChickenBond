Summary
 - [weak-prng](#weak-prng) (1 results) (High)
 - [unchecked-transfer](#unchecked-transfer) (14 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (8 results) (Medium)
 - [incorrect-equality](#incorrect-equality) (6 results) (Medium)
 - [reentrancy-no-eth](#reentrancy-no-eth) (2 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (7 results) (Medium)
 - [unused-return](#unused-return) (19 results) (Medium)
 - [missing-zero-check](#missing-zero-check) (3 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (4 results) (Low)
 - [timestamp](#timestamp) (7 results) (Low)
 - [solc-version](#solc-version) (17 results) (Informational)
 - [naming-convention](#naming-convention) (49 results) (Informational)
 - [too-many-digits](#too-many-digits) (2 results) (Informational)
## weak-prng
Impact: High
Confidence: Medium
 - [ ] ID-0
[ChickenMath.decPow(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59) uses a weak PRNG: "[n % 2 == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L48)" 

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59


## unchecked-transfer
Impact: High
Confidence: Medium
 - [ ] ID-1
[ChickenBondManager._shiftAllLUSDInSPToSilo()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L545-L555) ignores return value by [lusdToken.transfer(lusdSiloAddress,lusdBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L554)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L545-L555


 - [ ] ID-2
[ChickenBondManager.chickenIn(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330-L378) ignores return value by [lusdToken.transferFrom(lusdSiloAddress,msg.sender,lusdToRefund)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L367)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330-L378


 - [ ] ID-3
[ChickenBondManager.sendFeeShare(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559-L566) ignores return value by [lusdToken.transferFrom(yearnGovernanceAddress,address(this),_lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L564)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559-L566


 - [ ] ID-4
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) ignores return value by [yearnCurveVault.transfer(msg.sender,yTokensFromCurveVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L415)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-5
[ChickenBondOperationsScript.chickenIn(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L58-L69) ignores return value by [bLUSDToken.transfer(msg.sender,balanceAfter - balanceBefore)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L68)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L58-L69


 - [ ] ID-6
[ChickenBondManager.chickenOut(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259) ignores return value by [lusdToken.transferFrom(lusdSiloAddress,msg.sender,lusdToWithdraw)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L255)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259


 - [ ] ID-7
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) ignores return value by [yearnSPVault.transfer(msg.sender,yTokensFromSPVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L398)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-8
[ChickenBondOperationsScript.redeemAndWithdraw(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100) ignores return value by [bLUSDToken.transferFrom(msg.sender,address(this),_bLUSDToRedeem - proxyBalance)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L75)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100


 - [ ] ID-9
[ChickenBondOperationsScript.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34-L45) ignores return value by [lusdToken.transferFrom(msg.sender,address(this),_lusdAmount - proxyBalance)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L38)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34-L45


 - [ ] ID-10
[ChickenBondOperationsScript.chickenOut(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L47-L56) ignores return value by [lusdToken.transfer(msg.sender,lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L55)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L47-L56


 - [ ] ID-11
[ChickenBondManager.chickenOut(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259) ignores return value by [lusdToken.transfer(msg.sender,lusdBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L251)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259


 - [ ] ID-12
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) ignores return value by [lusdToken.transferFrom(lusdSiloAddress,msg.sender,lusdFromSilo)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L405)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-13
[ChickenBondManager.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209) ignores return value by [lusdToken.transferFrom(msg.sender,address(this),_lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L205)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209


 - [ ] ID-14
[ChickenBondOperationsScript.redeemAndWithdraw(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100) ignores return value by [lusdToken.transfer(msg.sender,lusdBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L99)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-15
[ChickenBondManager.shiftLUSDFromSPToCurve(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473) performs a multiplication on the result of a division:
	-[ratioPermanentToOwned = permanentLUSDInSP * 1e18 / lusdOwnedLUSDVault](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L438)
	-[permanentLUSDShifted = _lusdToShift * ratioPermanentToOwned / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L440)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473


 - [ ] ID-16
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) performs a multiplication on the result of a division:
	-[fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L389)
	-[lusdToWithdrawFromSP = _getAcquiredLUSDInSP(lusdInSP) * fractionOfAcquiredLUSDToWithdraw / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L395)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-17
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) performs a multiplication on the result of a division:
	-[fractionOfBLUSDToRedeem = _bLUSDToRedeem * 1e18 / bLUSDToken.totalSupply()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L385)
	-[fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L389)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-18
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) performs a multiplication on the result of a division:
	-[fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L389)
	-[lusdFromSilo = getAcquiredLUSDInSilo() * fractionOfAcquiredLUSDToWithdraw / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L403)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-19
[ChickenBondManager.redeem(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424) performs a multiplication on the result of a division:
	-[fractionOfAcquiredLUSDToWithdraw = fractionOfBLUSDToRedeem * (1e18 - redemptionFeePercentage) / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L389)
	-[lusdToWithdrawFromCurve = getAcquiredLUSDInCurve() * fractionOfAcquiredLUSDToWithdraw / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L411)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380-L424


 - [ ] ID-20
[ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525) performs a multiplication on the result of a division:
	-[ratioPermanentToOwned = permanentLUSDInCurve * 1e18 / lusdInCurve](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L507)
	-[permanentLUSDWithdrawn = lusdBalanceDelta * ratioPermanentToOwned / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L508)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


 - [ ] ID-21
[ChickenBondManager.shiftLUSDFromSPToCurve(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473) performs a multiplication on the result of a division:
	-[ratioPermanentToOwned = permanentLUSDInSP * 1e18 / lusdOwnedLUSDVault](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L438)
	-[permanentLUSDCurveIncrease = (lusdInCurve - lusdInCurveBefore) * ratioPermanentToOwned / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L466)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473


 - [ ] ID-22
[ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525) performs a multiplication on the result of a division:
	-[ratioPermanentToOwned = permanentLUSDInCurve * 1e18 / lusdInCurve](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L507)
	-[permanentLUSDIncrease = lusdBalanceDelta * ratioPermanentToOwned / 1e18](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L519)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-23
[ChickenMath.decPow(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59) uses a dangerous strict equality:
	- [_exponent == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L40)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59


 - [ ] ID-24
[ChickenBondManager._calcUpdatedAccrualParameter(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L644-L722) uses a dangerous strict equality:
	- [updatedAccrualAdjustmentPeriodCount == _storedAccrualAdjustmentCount || _storedAccrualParameter == minimumAccrualParameter || totalPendingLUSD == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L659-L663)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L644-L722


 - [ ] ID-25
[ChickenBondManager._calcAccruedBLUSD(uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L627-L640) uses a dangerous strict equality:
	- [_startTime == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L629)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L627-L640


 - [ ] ID-26
[ChickenBondManager._transferToRewardsStakingContract(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L262-L267) uses a dangerous strict equality:
	- [assert(bool)(lusdBalanceBefore - lusdToken.balanceOf(address(this)) == _lusdToTransfer)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L266)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L262-L267


 - [ ] ID-27
[ChickenMath.decPow(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59) uses a dangerous strict equality:
	- [n % 2 == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L48)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59


 - [ ] ID-28
[ChickenBondManager._withdrawFromSPVaultAndTransferToRewardsStakingContract(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L269-L281) uses a dangerous strict equality:
	- [lusdBalanceDelta == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L275)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L269-L281


## reentrancy-no-eth
Impact: Medium
Confidence: Medium
 - [ ] ID-29
Reentrancy in [ChickenBondManager.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209):
	External calls:
	- [bondID = bondNFT.mint(msg.sender)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L194)
	State variables written after the call(s):
	- [totalPendingLUSD += _lusdAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L202)
	- [totalWeightedStartTimes += _lusdAmount * block.timestamp](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L203)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209


 - [ ] ID-30
Reentrancy in [ChickenBondManager.chickenIn(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330-L378):
	External calls:
	- [_firstChickenIn()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L344)
		- [curveLiquidityGauge.deposit_reward_token(address(lusdToken),_lusdToTransfer)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L264)
		- [yearnCurveVault.withdraw(_yTokensToSwap)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L285)
		- [yearnSPVault.withdraw(_yTokensToSwap)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L272)
		- [curvePool.remove_liquidity_one_coin(LUSD3CRVBalanceDelta,INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL,0)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L291)
	State variables written after the call(s):
	- [delete idToBondData[_bondID]](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L351)
	- [permanentLUSDInSP += lusdSurplus](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L364)
	- [totalPendingLUSD -= bond.lusdAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L354)
	- [totalWeightedStartTimes -= bond.lusdAmount * bond.startTime](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L355)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330-L378


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-31
[ChickenBondManager.redeem(uint256).yTokensFromSPVault](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L393) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L393


 - [ ] ID-32
[ChickenBondManager.redeem(uint256).yTokensFromCurveVault](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L409) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L409


 - [ ] ID-33
[ChickenBondManager._getAcquiredLUSDInSP(uint256).acquiredLUSDInSP](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L770) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L770


 - [ ] ID-34
[ChickenBondManager.getAcquiredLUSDInCurve().acquiredLUSDInCurve](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L896) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L896


 - [ ] ID-35
[ChickenBondManager.createBond(uint256).bondData](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L197) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L197


 - [ ] ID-36
[ChickenBondManager.redeem(uint256).lusdFromSilo](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L401) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L401


 - [ ] ID-37
[ChickenBondManager.getTotalLPAndLUSDInCurve().totalLUSDInCurve](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L875) is a local variable never initialized

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L875


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-38
[ChickenBondOperationsScript.redeemAndWithdraw(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100) ignores return value by [yearnSPVault.withdraw(yTokensFromSPVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L85)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100


 - [ ] ID-39
[ChickenBondManager.chickenOut(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259) ignores return value by [yearnSPVault.withdraw(yTokensToSwapForLUSD)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L243)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216-L259


 - [ ] ID-40
[ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525) ignores return value by [yearnSPVault.deposit(lusdBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L515)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


 - [ ] ID-41
[ChickenBondManager.constructor(ChickenBondManager.ExternalAdresses,uint256,uint256,uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183) ignores return value by [lusdToken.approve(address(curveLiquidityGauge),MAX_UINT256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L175)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183


 - [ ] ID-42
[LUSDSilo.initialize(address)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11-L18) ignores return value by [lusdToken.approve(_chickenBondManagerAddress,type()(uint256).max)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L15)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11-L18


 - [ ] ID-43
[ChickenBondOperationsScript.constructor(IChickenBondManager)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L21-L32) ignores return value by [Address.isContract(address(_chickenBondManager))](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L22)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L21-L32


 - [ ] ID-44
[ChickenBondOperationsScript.redeemAndWithdraw(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100) ignores return value by [yearnCurveVault.withdraw(yTokensFromCurveVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L86)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71-L100


 - [ ] ID-45
[ChickenBondManager.constructor(ChickenBondManager.ExternalAdresses,uint256,uint256,uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183) ignores return value by [lusdToken.approve(address(curvePool),MAX_UINT256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L173)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183


 - [ ] ID-46
[ChickenBondManager.constructor(ChickenBondManager.ExternalAdresses,uint256,uint256,uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183) ignores return value by [lusdToken.approve(address(yearnSPVault),MAX_UINT256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L172)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183


 - [ ] ID-47
[ChickenBondManager.shiftLUSDFromSPToCurve(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473) ignores return value by [yearnCurveVault.deposit(lusd3CRVBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L461)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473


 - [ ] ID-48
[ChickenBondManager._shiftAllLUSDInSPToSilo()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L545-L555) ignores return value by [yearnSPVault.withdraw(yTokensToBurnFromLUSDVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L550)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L545-L555


 - [ ] ID-49
[ChickenBondManager.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209) ignores return value by [yearnSPVault.deposit(_lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L208)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209


 - [ ] ID-50
[ChickenBondManager.constructor(ChickenBondManager.ExternalAdresses,uint256,uint256,uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183) ignores return value by [curvePool.approve(address(yearnCurveVault),MAX_UINT256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L174)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L139-L183


 - [ ] ID-51
[ChickenBondOperationsScript.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34-L45) ignores return value by [lusdToken.approve(address(chickenBondManager),_lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L42)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34-L45


 - [ ] ID-52
[ChickenBondManager._withdrawFromSPVaultAndTransferToRewardsStakingContract(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L269-L281) ignores return value by [yearnSPVault.withdraw(_yTokensToSwap)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L272)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L269-L281


 - [ ] ID-53
[ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525) ignores return value by [yearnCurveVault.withdraw(yTokensToBurnFromCurveVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L492)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


 - [ ] ID-54
[ChickenBondManager._withdrawFromCurveVaultAndTransferToRewardsStakingContract(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L283-L296) ignores return value by [yearnCurveVault.withdraw(_yTokensToSwap)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L285)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L283-L296


 - [ ] ID-55
[ChickenBondManager.shiftLUSDFromSPToCurve(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473) ignores return value by [yearnSPVault.withdraw(yTokensToBurnFromLUSDVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L446)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473


 - [ ] ID-56
[ChickenBondManager.sendFeeShare(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559-L566) ignores return value by [yearnSPVault.deposit(_lusdAmount)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L565)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559-L566


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-57
[BondNFT.setAddresses(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L17) lacks a zero-check on :
		- [chickenBondManagerAddress = _chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L18)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L17


 - [ ] ID-58
[LUSDSilo.initialize(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11) lacks a zero-check on :
		- [chickenBondManagerAddress = _chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L13)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11


 - [ ] ID-59
[BLUSDToken.setAddresses(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L14) lacks a zero-check on :
		- [chickenBondManagerAddress = _chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L15)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L14


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-60
Reentrancy in [ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525):
	External calls:
	- [yearnCurveVault.withdraw(yTokensToBurnFromCurveVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L492)
	- [curvePool.remove_liquidity_one_coin(lusd3CRVBalanceDelta,INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL,0)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L502)
	State variables written after the call(s):
	- [permanentLUSDInCurve -= permanentLUSDWithdrawn](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L509)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


 - [ ] ID-61
Reentrancy in [ChickenBondManager.shiftLUSDFromCurveToSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525):
	External calls:
	- [yearnCurveVault.withdraw(yTokensToBurnFromCurveVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L492)
	- [curvePool.remove_liquidity_one_coin(lusd3CRVBalanceDelta,INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL,0)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L502)
	- [yearnSPVault.deposit(lusdBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L515)
	State variables written after the call(s):
	- [permanentLUSDInSP += permanentLUSDIncrease](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L520)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475-L525


 - [ ] ID-62
Reentrancy in [ChickenBondManager.createBond(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209):
	External calls:
	- [bondID = bondNFT.mint(msg.sender)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L194)
	State variables written after the call(s):
	- [idToBondData[bondID] = bondData](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L200)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187-L209


 - [ ] ID-63
Reentrancy in [ChickenBondManager.shiftLUSDFromSPToCurve(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473):
	External calls:
	- [yearnSPVault.withdraw(yTokensToBurnFromLUSDVault)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L446)
	- [curvePool.add_liquidity((lusdBalanceDelta,0),0)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L456)
	- [yearnCurveVault.deposit(lusd3CRVBalanceDelta)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L461)
	State variables written after the call(s):
	- [permanentLUSDInCurve += permanentLUSDCurveIncrease](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L468)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426-L473


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-64
[ChickenBondManager._calcUpdatedAccrualParameter(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L644-L722) uses timestamp for comparisons
	Dangerous comparisons:
	- [updatedAccrualAdjustmentPeriodCount == _storedAccrualAdjustmentCount || _storedAccrualParameter == minimumAccrualParameter || totalPendingLUSD == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L659-L663)
	- [updatedAccrualAdjustmentPeriodCount < adjustmentPeriodCountWhenTargetIsExceeded](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L708)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L644-L722


 - [ ] ID-65
[ChickenBondManager._firstChickenIn()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L300-L328) uses timestamp for comparisons
	Dangerous comparisons:
	- [lusdFromInitialYieldInSP > 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L309)
	- [yTokensFromSPVault > 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L311)
	- [yTokensFromCurveVault > 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L324)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L300-L328


 - [ ] ID-66
[ChickenBondManager._getAcquiredLUSDInSP(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L757-L778) uses timestamp for comparisons
	Dangerous comparisons:
	- [_lusdInSP > pendingLUSDInSPVault + permanentLUSDInSPCached](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L773)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L757-L778


 - [ ] ID-67
[ChickenBondManager._requireNonZeroAmount(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L814-L816) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(_amount > 0,CBM: Amount must be > 0)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L815)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L814-L816


 - [ ] ID-68
[ChickenBondManager._updateRedemptionFeePercentage(uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L591-L604) uses timestamp for comparisons
	Dangerous comparisons:
	- [timePassed >= SECONDS_IN_ONE_MINUTE](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L598)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L591-L604


 - [ ] ID-69
[ChickenBondManager._calcAccruedBLUSD(uint256,uint256,uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L627-L640) uses timestamp for comparisons
	Dangerous comparisons:
	- [_startTime == 0](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L629)
	- [assert(bool)(accruedBLUSD < bondBLUSDCap)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L637)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L627-L640


 - [ ] ID-70
[ChickenBondManager._updateAccrualParameter()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L724-L740) uses timestamp for comparisons
	Dangerous comparisons:
	- [updatedAccrualAdjustmentPeriodCount != storedAccrualAdjustmentPeriodCount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L731)
	- [updatedAccrualParameter != storedAccrualParameter](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L734)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L724-L740


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-71
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IYearnRegistry.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IYearnRegistry.sol#L1


 - [ ] ID-72
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L3) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L3


 - [ ] ID-73
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L1


 - [ ] ID-74
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/BaseMath.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/BaseMath.sol#L2


 - [ ] ID-75
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L2


 - [ ] ID-76
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IBondNFT.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IBondNFT.sol#L2


 - [ ] ID-77
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L2


 - [ ] ID-78
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IYearnVault.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IYearnVault.sol#L2


 - [ ] ID-79
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L2


 - [ ] ID-80
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ILUSDToken.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ILUSDToken.sol#L2


 - [ ] ID-81
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IBLUSDToken.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IBLUSDToken.sol#L2


 - [ ] ID-82
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L1


 - [ ] ID-83
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L2) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L2


 - [ ] ID-84
solc-0.8.13 is not recommended for deployment

 - [ ] ID-85
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L1


 - [ ] ID-86
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IChickenBondManager.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IChickenBondManager.sol#L1


 - [ ] ID-87
Pragma version[^0.8.10](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/StrategyAPI.sol#L1) necessitates a version too recent to be trusted. Consider deploying with 0.6.12/0.7.6/0.8.7

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/StrategyAPI.sol#L1


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-88
Function [ICurveLiquidityGaugeV4.add_reward(address,address)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L5) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L5


 - [ ] ID-89
Parameter [ChickenBondManager.calcRedemptionFeePercentage(uint256)._fractionOfBLUSDToRedeem](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L576) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L576


 - [ ] ID-90
Function [ICurveLiquidityGaugeV4.reward_data(address)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L7) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L7


 - [ ] ID-91
Parameter [BLUSDToken.mint(address,uint256)._to](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L19) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L19


 - [ ] ID-92
Parameter [ICurvePool.remove_liquidity(uint256,uint256[2]).burn_amount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9


 - [ ] ID-93
Parameter [ICurveLiquidityGaugeV4.deposit_reward_token(address,uint256)._reward_token](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L6) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L6


 - [ ] ID-94
Parameter [ChickenBondManager.shiftLUSDFromSPToCurve(uint256)._lusdToShift](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L426


 - [ ] ID-95
Function [ICurvePool.remove_liquidity_one_coin(uint256,int128,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11


 - [ ] ID-96
Parameter [ChickenBondOperationsScript.redeemAndWithdraw(uint256)._bLUSDToRedeem](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L71


 - [ ] ID-97
Parameter [ChickenBondManager.sendFeeShare(uint256)._lusdAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L559


 - [ ] ID-98
Parameter [BLUSDToken.burn(address,uint256)._from](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L24) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L24


 - [ ] ID-99
Parameter [BondNFT.mint(address)._bonder](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L22) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L22


 - [ ] ID-100
Variable [ChickenBondOperationsScript.INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L19) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L19


 - [ ] ID-101
Parameter [BondNFT.setAddresses(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L17) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L17


 - [ ] ID-102
Parameter [ChickenBondOperationsScript.chickenOut(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L47) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L47


 - [ ] ID-103
Parameter [ICurvePool.calc_withdraw_one_coin(uint256,int128)._burn_amount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L13) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L13


 - [ ] ID-104
Variable [ChickenBondManager.CHICKEN_IN_AMM_FEE](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L39) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L39


 - [ ] ID-105
Parameter [BondNFT.burn(uint256)._tokenID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L33) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BondNFT.sol#L33


 - [ ] ID-106
Parameter [ICurvePool.add_liquidity(uint256[2],uint256)._min_mint_amount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L7) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L7


 - [ ] ID-107
Parameter [ICurveLiquidityGaugeV4.add_reward(address,address)._reward_token](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L5) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L5


 - [ ] ID-108
Parameter [ChickenBondManager.redeem(uint256)._bLUSDToRedeem](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L380


 - [ ] ID-109
Function [IChickenBondManager.INDEX_OF_LUSD_TOKEN_IN_CURVE_POOL()](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IChickenBondManager.sol#L16) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/IChickenBondManager.sol#L16


 - [ ] ID-110
Parameter [ChickenMath.decPow(uint256,uint256)._exponent](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36


 - [ ] ID-111
Function [ICurvePool.calc_withdraw_one_coin(uint256,int128)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L13) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L13


 - [ ] ID-112
Parameter [BLUSDToken.setAddresses(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L14) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L14


 - [ ] ID-113
Parameter [ChickenBondManager.chickenIn(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L330


 - [ ] ID-114
Function [ICurvePool.add_liquidity(uint256[2],uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L7) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L7


 - [ ] ID-115
Function [ICurvePool.remove_liquidity(uint256,uint256[2])](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9


 - [ ] ID-116
Parameter [ICurvePool.remove_liquidity_one_coin(uint256,int128,uint256)._min_received](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11


 - [ ] ID-117
Parameter [ChickenBondManager.calcAccruedBLUSD(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L839) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L839


 - [ ] ID-118
Parameter [ChickenBondManager.getIdToBondData(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L834) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L834


 - [ ] ID-119
Parameter [ICurvePool.remove_liquidity_one_coin(uint256,int128,uint256)._burn_amount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L11


 - [ ] ID-120
Function [ICurvePool.calc_token_amount(uint256[2],bool)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L15) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L15


 - [ ] ID-121
Parameter [ICurveLiquidityGaugeV4.reward_data(address)._reward_token](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L7) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L7


 - [ ] ID-122
Parameter [ChickenBondManager.calcBondBLUSDCap(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L845) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L845


 - [ ] ID-123
Parameter [ChickenBondOperationsScript.chickenIn(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L58) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L58


 - [ ] ID-124
Parameter [BLUSDToken.mint(address,uint256)._bLUSDAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L19) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L19


 - [ ] ID-125
Function [ICurveLiquidityGaugeV4.deposit_reward_token(address,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L6) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurveLiquidityGaugeV4.sol#L6


 - [ ] ID-126
Function [ICurvePool.get_dy_underlying(int128,int128,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L21) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L21


 - [ ] ID-127
Parameter [ChickenBondManager.shiftLUSDFromCurveToSP(uint256)._lusdToShift](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L475


 - [ ] ID-128
Parameter [ICurvePool.remove_liquidity(uint256,uint256[2])._min_amounts](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L9


 - [ ] ID-129
Parameter [ChickenBondManager.createBond(uint256)._lusdAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L187


 - [ ] ID-130
Parameter [ChickenMath.decPow(uint256,uint256)._base](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36


 - [ ] ID-131
Parameter [ChickenBondOperationsScript.createBond(uint256)._lusdAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Proxy/ChickenBondOperationsScript.sol#L34


 - [ ] ID-132
Parameter [LUSDSilo.initialize(address)._chickenBondManagerAddress](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/LUSDSilo.sol#L11


 - [ ] ID-133
Parameter [ChickenBondManager.getBondData(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L830) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L830


 - [ ] ID-134
Parameter [ChickenBondManager.chickenOut(uint256)._bondID](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/ChickenBondManager.sol#L216


 - [ ] ID-135
Parameter [BLUSDToken.burn(address,uint256)._bLUSDAmount](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L24) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/BLUSDToken.sol#L24


 - [ ] ID-136
Parameter [ICurvePool.calc_token_amount(uint256[2],bool)._is_deposit](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L15) is not in mixedCase

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/Interfaces/ICurvePool.sol#L15


## too-many-digits
Impact: Informational
Confidence: Medium
 - [ ] ID-137
[ChickenMath.decPow(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59) uses literals with too many digits:
	- [_exponent > 525600000](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L38)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59


 - [ ] ID-138
[ChickenMath.decPow(uint256,uint256)](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59) uses literals with too many digits:
	- [_exponent = 525600000](https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L38)

https://github.com/liquity/ChickenBond/blob/e2e993e50943b3fed6ad17b62d7137f4ff0ad5fb/LUSDChickenBonds/src/utils/ChickenMath.sol#L36-L59


