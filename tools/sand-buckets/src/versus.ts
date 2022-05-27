import { Command } from "fast-check";

import {
  ChickenBondsImplementation,
  ChickenBondsMethods,
  ChickenBondsModel,
  ChickenBondsModelState,
  ChickenBondsPureCommand
} from "./types";

export const versusCmd =
  (assertions: (m: Readonly<ChickenBondsModelState>, r: Readonly<ChickenBondsModelState>) => void) =>
  <A extends unknown[]>(
    createPureCmd: (...args: A) => ChickenBondsPureCommand,
    runReal: (r: ChickenBondsImplementation, ...args: A) => void
  ) =>
  (...args: A): Command<ChickenBondsModelState, ChickenBondsImplementation> => {
    const { toString, check, run } = createPureCmd(...args);

    return {
      toString,
      check,
      run: (m, r) => {
        Object.assign(m, run(m));
        runReal(r, ...args);
        assertions(m, r.getState());
      }
    };
  };

export const versus =
  (assertions: (m: Readonly<ChickenBondsModelState>, r: Readonly<ChickenBondsModelState>) => void) =>
  (
    model: ChickenBondsModel
  ): ChickenBondsMethods<Command<ChickenBondsModelState, ChickenBondsImplementation>> => {
    const runBothAndAssert = versusCmd(assertions);

    return {
      createBond: runBothAndAssert(model.createBond, (r, ...args) => r.createBond(...args)),
      chickenOut: runBothAndAssert(model.chickenOut, (r, ...args) => r.chickenOut(...args)),
      chickenIn: runBothAndAssert(model.chickenIn, (r, ...args) => r.chickenIn(...args)),
      harvestA: runBothAndAssert(model.harvestA, (r, ...args) => r.harvestA(...args)),
      harvestB: runBothAndAssert(model.harvestB, (r, ...args) => r.harvestB(...args)),
      shiftA2B: runBothAndAssert(model.shiftA2B, (r, ...args) => r.shiftA2B(...args)),
      shiftB2A: runBothAndAssert(model.shiftB2A, (r, ...args) => r.shiftB2A(...args))
    };
  };
