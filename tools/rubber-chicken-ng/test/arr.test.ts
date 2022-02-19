import fc from "fast-check";

const monotonicallyIncreasing = (f: (x: number) => number, min: number, max: number) => {
  // if (f(min) > f(max)) {
  //   console.log(`f(${min}) = ${f(min)}, f(${max}) = ${f(max)}`);
  // }
  return f(min) <= f(max);
};

const monotonicallyDecreasing = (f: (x: number) => number, min: number, max: number) => {
  // if (f(min) < f(max)) {
  //   console.log(`f(${min}) = ${f(min)}, f(${max}) = ${f(max)}`);
  // }
  return f(min) >= f(max);
};

const chickenUpRoi =
  (polRatio: number, premium: number, curve: (dt: number) => number) => (dt: number) =>
    curve(dt) < 1 / polRatio
      ? polRatio * (1 + premium) * curve(dt) - 1
      : polRatio * premium * curve(dt);

const annualized = (r: (dt: number) => number) => (dt: number) => Math.pow(1 + r(dt), 1 / dt) - 1;

const positive = (x: number) => x > 0;

const arbitraryParams = () =>
  fc
    .record({
      polRatio: fc
        .float()
        .filter(positive)
        .map(x => 1 / x),
      premium: fc
        .float()
        .filter(positive)
        .map(x => 1 / x),

      T: fc.float().filter(positive)
    })
    .chain(params => orderedPair().map(pair => ({ ...params, ...pair })));

const orderedPair = () =>
  fc.tuple(fc.float().filter(positive), fc.float().filter(positive)).map(([a, b]) => ({
    min: Math.min(a, b),
    max: Math.max(a, b)
  }));

const cappedLinearCurve = (T: number) => (dt: number) => Math.min(dt / T, 1);

describe("In case of linear accrual", () => {
  describe("ARR before reaching the cap", () => {
    it("should monotonically increase", () => {
      fc.assert(
        fc.property(
          arbitraryParams()
            .filter(({ polRatio, T, min, max }) => {
              const curve = cappedLinearCurve(T);
              const cap = 1 / polRatio;

              return curve(min) < cap && curve(max) < cap;
            })
            .noShrink(),
          ({ polRatio, premium, T, min, max }) =>
            monotonicallyIncreasing(
              annualized(chickenUpRoi(polRatio, premium, cappedLinearCurve(T))),
              min,
              max
            )
        ),
        { numRuns: 10000 }
      );
    });
  });

  describe("ARR after reaching the cap", () => {
    it("should monotonically decrease", () => {
      fc.assert(
        fc.property(
          arbitraryParams()
            .filter(({ polRatio, T, min, max }) => {
              const curve = cappedLinearCurve(T);
              const cap = 1 / polRatio;

              return curve(min) > cap && curve(max) > cap;
            })
            .noShrink(),
          ({ polRatio, premium, T, min, max }) =>
            monotonicallyDecreasing(
              annualized(chickenUpRoi(polRatio, premium, cappedLinearCurve(T))),
              min,
              max
            )
        ),
        { numRuns: 10000 }
      );
    });
  });
});
