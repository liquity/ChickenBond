export interface ChickenBondsModelState {
  pending: number;
  acquiredA: number;
  acquiredB: number;
  permanentA: number;
  permanentB: number;
}

export interface ChickenBondsPureCommand {
  toString: () => string;
  check: (s: Readonly<ChickenBondsModelState>) => boolean;
  run: (s: Readonly<ChickenBondsModelState>) => ChickenBondsModelState;
}

export interface ChickenBondsModel {
  createBond(positiveAmount: number): ChickenBondsPureCommand;
  chickenOut(positiveAmount: number): ChickenBondsPureCommand;
  chickenIn(positiveAmount: number, zeroToOneAccruedFraction: number): ChickenBondsPureCommand;

  harvestA(amount: number): ChickenBondsPureCommand;
  harvestB(amount: number): ChickenBondsPureCommand;

  shiftA2B(positiveAmount: number): ChickenBondsPureCommand;
  shiftB2A(positiveAmount: number): ChickenBondsPureCommand;
}

export type ChickenBondsMethods<T> = {
  [P in keyof ChickenBondsModel]: ChickenBondsModel[P] extends (...args: infer A) => unknown
    ? (...args: A) => T
    : never;
};

export interface ChickenBondsImplementation extends ChickenBondsMethods<void> {
  getState(): ChickenBondsModelState;
}
