import { expect } from "chai";
import { testProp, fc } from "ava-fast-check";

import { ChickenBondsModelState } from "../src/bonds/types";
import { versus } from "../src/bonds/versus";
import { simpleModel } from "../src/bonds/simple";
import { ChickenBondsVaultBasedImplementation } from "../src/bonds/vaults";

const assertRoughlyEq = (a: number, b: number) => {
  expect(a).to.be.approximately(b, 1e-9);
};

const assertRoughlySameState = (
  a: Readonly<ChickenBondsModelState>,
  b: Readonly<ChickenBondsModelState>
) => {
  assertRoughlyEq(a.pending, b.pending);
  assertRoughlyEq(a.acquiredA, b.acquiredA);
  assertRoughlyEq(a.acquiredB, b.acquiredB);
  assertRoughlyEq(a.permanentA, b.permanentA);
  assertRoughlyEq(a.permanentB, b.permanentB);
};

const positiveAmount = () => fc.float().filter(x => x > 0);

const cmd = versus(assertRoughlySameState)(simpleModel());
const createBond = () => positiveAmount().map(cmd.createBond);
const chickenOut = () => positiveAmount().map(cmd.chickenOut);
const chickenIn = () => fc.tuple(positiveAmount(), fc.float()).map(args => cmd.chickenIn(...args));
const harvestA = () => fc.float().map(cmd.harvestA);
const harvestB = () => fc.float().map(cmd.harvestB);
const shiftA2B = () => positiveAmount().map(cmd.shiftA2B);
const shiftB2A = () => positiveAmount().map(cmd.shiftB2A);

const setup: fc.ModelRunSetup<
  ChickenBondsModelState,
  ChickenBondsVaultBasedImplementation
> = () => ({
  model: {
    pending: 0,
    acquiredA: 0,
    acquiredB: 0,
    permanentA: 0,
    permanentB: 0
  },

  real: new ChickenBondsVaultBasedImplementation()
});

const arbitraryCommands = () =>
  fc.commands(
    [createBond(), chickenOut(), chickenIn(), harvestA(), harvestB(), shiftA2B(), shiftB2A()],
    {}
  );

testProp(
  "Vault-based implementation should behave according to the simple model",
  [arbitraryCommands()],
  (t, commands) => t.notThrows(() => fc.modelRun(setup, commands)),
  { numRuns: 10000 }
);

// const logCmd = versus((m, r) => {
//   console.log(m);
//   console.log(r);
// })(simpleModel());

// const logCmds = [
//   logCmd.createBond(50),
//   logCmd.createBond(50),
//   logCmd.chickenIn(50, 0.8),
//   logCmd.shiftA2B(25),
//   logCmd.shiftA2B(25)
// ];

// fc.modelRun(setup, logCmds);
