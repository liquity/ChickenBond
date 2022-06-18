import assert from "assert";

const MAX_ITERATIONS = 256;
const EPSILON = 1e-6;

export const id = <T>(x: T) => x;

export const nonNegative = (x: number) => x >= 0;
export const positive = (x: number) => x > 0;
export const nonZero = (x: number) => x !== 0;
export const inRange = (a: number, b: number) => (x: number) => a <= x && x <= b;

export const add = (a: number, b: number) => a + b;
export const sub = (a: number, b: number) => a - b;
export const mul = (a: number, b: number) => a * b;
export const div = (a: number, b: number) => a / b;

export const sum = (x: number[]) => x.reduce(add, 0);
export const prod = (x: number[]) => x.reduce(mul, 1);

export const zeros = (n: number) => new Array<number>(n).fill(0);
export const ones = (n: number) => new Array<number>(n).fill(1);

export const set = <T>(arr: T[], i: number, newValue: T) =>
  arr.map((oldValue, k) => (k === i ? newValue : oldValue));

export const mapAdd = (as: number[], b: number) => as.map(a => a + b);
export const mapSub = (as: number[], b: number) => as.map(a => a - b);
export const mapMul = (as: number[], b: number) => as.map(a => a * b);
export const mapDiv = (as: number[], b: number) => as.map(a => a / b);

export const zipWith =
  <T, U, V>(f: (t: T, u: U) => V) =>
  (ts: T[], us: U[]) =>
    ts.map((t, i) => f(t, us[i]));

export const zipAdd = zipWith(add);
export const zipSub = zipWith(sub);
export const zipMul = zipWith(mul);
export const zipDiv = zipWith(div);

export const approxZero =
  (epsilon = EPSILON) =>
  (x: number) =>
    Math.abs(x) < epsilon;

export const approxEq =
  (epsilon = EPSILON) =>
  (a: number, b: number) =>
    approxZero(epsilon)(a - b);

export const iterate =
  <T>(found: (curr: T, prev: T) => boolean, maxIterations = MAX_ITERATIONS) =>
  (first: T, getNext: (prev: T) => T): T => {
    let prev = first;

    for (let i = 0; i < maxIterations; i++) {
      const curr = getNext(prev);

      if (found(curr, prev)) {
        return curr;
      }

      prev = curr;
    }

    throw new Error(`not found within ${maxIterations} iterations`);
  };

export const converge = iterate(approxEq());

export const binSearchDesc = (min: number, max: number, epsilon = EPSILON) => {
  assert(min <= max);

  return <T extends unknown[]>(f: (x: number) => [y: number, ...rest: T]) =>
    (yToFind: number): [x: number, ...rest: T] => {
      let left = min;
      let right = max;

      for (;;) {
        const x = (left + right) / 2;
        const [y, ...rest] = f(x);
        const diff = yToFind - y;

        if (approxZero(epsilon)(diff)) {
          return [x, ...rest];
        }

        if (diff < 0) {
          left = x;
        } else {
          right = x;
        }
      }
    };
};

// export const compose2 =
//   <T extends unknown[], U, V>(g: (_: U) => V, f: (..._: T) => U) =>
//   (...t: T): V =>
//     g(f(...t));

// export const compose3 =
//   <T extends unknown[], U, V, W>(h: (_: V) => W, g: (_: U) => V, f: (..._: T) => U) =>
//   (...t: T): W =>
//     h(g(f(...t)));

export const flow2 =
  <T extends unknown[], U, V>(f: (..._: T) => U, g: (_: U) => V) =>
  (...t: T): V =>
    g(f(...t));

export const flow3 =
  <T extends unknown[], U, V, W>(f: (..._: T) => U, g: (_: U) => V, h: (_: V) => W) =>
  (...t: T): W =>
    h(g(f(...t)));

// export const flip =
//   <T extends unknown[], U extends unknown[], V>(f: (..._: T) => (..._: U) => V) =>
//   (...u: U) =>
//   (...t: T): V =>
//     f(...t)(...u);

export const check = (requirement: boolean, message: string) => {
  if (!requirement) {
    throw new Error(message);
  }
};

export const wrap =
  <A extends unknown[], R>(f: (...args: A) => R) =>
  (...args: A) =>
    f(...args);
