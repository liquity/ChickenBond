import { ChickenBondsImplementation, ChickenBondsModelState } from "./types";

class Vault {
  deposited = 0;
  price = 1;

  deposit(underlying: number): number {
    this.deposited += underlying;
    return underlying / this.price;
  }

  withdraw(derivative: number): number {
    this.deposited -= derivative * this.price;
    return derivative * this.price;
  }

  harvest(underlying: number) {
    this.price *= (this.deposited + underlying) / this.deposited;
    this.deposited += underlying;
  }
}

export class ChickenBondsVaultBasedImplementation implements ChickenBondsImplementation {
  private _pending = 0;
  private _permanentA = 0;
  private _permanentB = 0;
  private _yA = 0;
  private _yB = 0;
  private _vaultA = new Vault();
  private _vaultB = new Vault();

  getState(): ChickenBondsModelState {
    return {
      pending: this._pending,
      permanentA: this._permanentA,
      permanentB: this._permanentB,
      acquiredA: this._yA * this._vaultA.price - this._permanentA - this._pending,
      acquiredB: this._yB * this._vaultB.price - this._permanentB
    };
  }

  createBond(underlying: number) {
    this._pending += underlying;
    this._yA += this._vaultA.deposit(underlying);
  }

  chickenOut(underlying: number) {
    const totalA = this._yA * this._vaultA.price;

    const derivative = this._yA * (Math.min(underlying, totalA) / totalA);
    this._pending -= this._vaultA.withdraw(derivative);
    this._yA -= derivative;
  }

  chickenIn(underlying: number, accruedFraction: number) {
    this._pending -= underlying;
    this._permanentA += underlying * (1 - accruedFraction);
  }

  harvestA(amount: number) {
    this._vaultA.harvest(amount);
  }

  harvestB(amount: number) {
    this._vaultB.harvest(amount);
  }

  shiftA2B(underlying: number) {
    const totalA = this._yA * this._vaultA.price;
    const ownedA = totalA - this._pending;
    const permanentPerOwnedA = this._permanentA / ownedA;

    this._permanentA -= underlying * permanentPerOwnedA;

    const derivative = this._yA * (underlying / totalA);
    const underlyingDelta = this._vaultA.withdraw(derivative);
    this._yA -= derivative;

    const totalBBefore = this._yB * this._vaultB.price;
    this._yB += this._vaultB.deposit(underlyingDelta);
    const totalB = this._yB * this._vaultB.price;

    this._permanentB += (totalB - totalBBefore) * permanentPerOwnedA;
  }

  shiftB2A(underlying: number) {
    const totalB = this._yB * this._vaultB.price;

    const derivative = this._yB * (underlying / totalB);
    const underlyingDelta = this._vaultB.withdraw(derivative);
    this._yB -= derivative;

    const permanentPerOwnedB = this._permanentB / totalB;
    this._permanentB -= underlyingDelta * permanentPerOwnedB;

    this._yA += this._vaultA.deposit(underlyingDelta);

    this._permanentA += underlyingDelta * permanentPerOwnedB;
  }
}
