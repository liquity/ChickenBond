import { ChickenBondsModel } from "./types";

export const simpleModel = (): ChickenBondsModel => ({
  createBond: positiveAmount => ({
    toString: () => `createBond(${positiveAmount})`,
    check: () => true,
    run: s => ({ ...s, pending: s.pending + positiveAmount })
  }),

  chickenOut: positiveAmount => ({
    toString: () => `chickenOut(${positiveAmount})`,
    check: s => positiveAmount <= s.pending,
    run: s => ({ ...s, pending: s.pending - positiveAmount })
  }),

  chickenIn: (positiveAmount, zeroToOneAccruedFraction) => ({
    toString: () => `chickenIn(${positiveAmount}, ${zeroToOneAccruedFraction})`,
    check: s => positiveAmount <= s.pending,
    run: s => ({
      ...s,
      pending: s.pending - positiveAmount,
      acquiredA: s.acquiredA + positiveAmount * zeroToOneAccruedFraction,
      permanentA: s.permanentA + positiveAmount * (1 - zeroToOneAccruedFraction)
    })
  }),

  harvestA: amount => ({
    toString: () => `harvestA(${amount})`,
    check: s => s.acquiredA + s.permanentA > 0 && amount >= -(s.acquiredA + s.permanentA),
    run: s => ({ ...s, acquiredA: s.acquiredA + amount })
  }),

  harvestB: amount => ({
    toString: () => `harvestB(${amount})`,
    check: s => s.acquiredB + s.permanentB > 0 && amount >= -(s.acquiredB + s.permanentB),
    run: s => ({ ...s, acquiredB: s.acquiredB + amount })
  }),

  shiftA2B: positiveAmount => ({
    toString: () => `shiftA2B(${positiveAmount})`,
    check: s => positiveAmount <= s.acquiredA + s.permanentA,
    run: s => {
      const zeroToOneShiftedFraction = positiveAmount / (s.acquiredA + s.permanentA);

      return {
        ...s,
        acquiredA: s.acquiredA - s.acquiredA * zeroToOneShiftedFraction,
        acquiredB: s.acquiredB + s.acquiredA * zeroToOneShiftedFraction,
        permanentA: s.permanentA - s.permanentA * zeroToOneShiftedFraction,
        permanentB: s.permanentB + s.permanentA * zeroToOneShiftedFraction
      };
    }
  }),

  shiftB2A: positiveAmount => ({
    toString: () => `shiftB2A(${positiveAmount})`,
    check: s => positiveAmount <= s.acquiredB + s.permanentB,
    run: s => {
      const zeroToOneShiftedFraction = positiveAmount / (s.acquiredB + s.permanentB);

      return {
        ...s,
        acquiredB: s.acquiredB - s.acquiredB * zeroToOneShiftedFraction,
        acquiredA: s.acquiredA + s.acquiredB * zeroToOneShiftedFraction,
        permanentB: s.permanentB - s.permanentB * zeroToOneShiftedFraction,
        permanentA: s.permanentA + s.permanentB * zeroToOneShiftedFraction
      };
    }
  })
});
