export interface Pair {
  readonly TOKEN: number;
  readonly sTOKEN: number;
}

export const ZEROES: Pair = { TOKEN: 0, sTOKEN: 0 };

export const calculateRatio = ({ TOKEN, sTOKEN }: Pair): number => TOKEN / sTOKEN;

export const addPair = (a: Pair, b: Pair): Pair => ({
  TOKEN: a.TOKEN + b.TOKEN,
  sTOKEN: a.sTOKEN + b.sTOKEN
});

export const subPair = (a: Pair, b: Pair): Pair => ({
  TOKEN: a.TOKEN - b.TOKEN,
  sTOKEN: a.sTOKEN - b.sTOKEN
});

export const addToken = (p: Pair, TOKEN: number): Pair => addPair(p, { TOKEN, sTOKEN: 0 });
export const subToken = (p: Pair, TOKEN: number): Pair => subPair(p, { TOKEN, sTOKEN: 0 });

export const lowpass =
  (alpha: number, y = 0) =>
  <T>(f: (x: T) => number) =>
  (x: T): number =>
    (y = alpha * f(x) + (1 - alpha) * y);

export const panic = <T>(errorMessage: string): T => {
  throw new Error(errorMessage);
};

export const box = (x: unknown): unknown[] => (x != null ? (Array.isArray(x) ? x : [x]) : []);

export const collectSamples = <T>(n: number, f: () => T): T[] => {
  const samples: T[] = new Array(n);

  for (let i = 0; i < n; ++i) {
    samples[i] = f();
  }

  return samples;
};

export const csv = (data: Record<string, number>[]) =>
  [Object.keys(data[0]), ...data.map(datum => Object.values(datum))]
    .map(datum => datum.join(","))
    .join("\n");

export const flatten = (
  data: Record<string, number | Record<string, number>>[]
): Record<string, number>[] =>
  data.map(datum =>
    Object.fromEntries(
      Object.entries(datum).flatMap(([k, v]) =>
        typeof v === "object" ? Object.entries(v).map(([k2, v2]) => [`${k}_${k2}`, v2]) : [[k, v]]
      )
    )
  );

export const PID =
  (Ts: number, ePrev = 0, i = 0) =>
  (Kp: number, Ki: number, Kd: number, e: number) =>
    Kp * e + Ki * (i += e * Ts) + Kd * ((-ePrev + (ePrev = e)) / Ts);

export const randomBinomial = (n: number, p: number) => {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("randomBinomial: n must be an integer >= 0");
  }

  if (p < 0 || p > 1) {
    throw new Error("randomBinomial: p must be in range [0,1]");
  }

  if (n === 0 || p === 0) {
    return 0;
  }

  if (p === 1) {
    return n;
  }

  const logQ = Math.log(1 - p);
  let x = 0;
  let sum = 0;

  for (;;) {
    sum += Math.log(Math.random()) / (n - x);
    if (sum < logQ) {
      return x;
    }
    ++x;
  }
};

export const round = (n: number, digits = 2) => `${Math.round(n * 10 ** digits) / 10 ** digits}`;
export const percent = (n: number, digits = 2) => `${round(n * 100, digits)}%`;

export const months = (periods: number) =>
  [...new Array(Math.floor(12 * periods)).keys()].map(i => 30 * (i + 1));
