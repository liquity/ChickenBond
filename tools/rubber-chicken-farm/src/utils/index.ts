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
