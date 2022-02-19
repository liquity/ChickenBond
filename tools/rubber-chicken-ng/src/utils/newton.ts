const tolerance = 1e-7;
const epsilon = 1e-14; // don't divide by a number smaller than this
const maxIterations = 100;

export interface NewtonRaphsonParams {
  f: (x: number) => number;
  fPrime: (x: number) => number;
  x0: number;
}

export const newtonRaphson = ({ f, fPrime, x0 }: NewtonRaphsonParams): number | null => {
  for (let i = 0; i < maxIterations; ++i) {
    const yPrime = fPrime(x0);

    if (Math.abs(yPrime) < epsilon) {
      return null;
    }

    const y = f(x0);
    const x1 = x0 - y / yPrime;

    if (Math.abs(x1 - x0) <= tolerance) {
      return x1;
    }

    x0 = x1;
  }

  return null;
};
