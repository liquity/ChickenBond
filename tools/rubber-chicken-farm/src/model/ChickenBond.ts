import { Pair, panic } from "../utils";

export interface ChickenBondDatum {
  k: number;
  dk: number;
  c: number;
  sTOKEN: number;
  tollTOKEN: number;
}

export interface ChickenBondCurve {
  (dk: number, u: number): number;
}

export class ChickenBond implements Pair {
  readonly k0;
  readonly TOKEN;
  readonly data: ChickenBondDatum[] = [];

  private readonly _curve;

  constructor(curve: ChickenBondCurve, k0: number, TOKEN: number) {
    this._curve = curve;
    this.k0 = k0;
    this.TOKEN = TOKEN;
  }

  peek(k: number, u: number, polRatio: number): ChickenBondDatum {
    const dk = k - this.k0;
    const c = this._curve(dk, u);

    return {
      k,
      dk,
      c,
      sTOKEN: (this.TOKEN / polRatio) * c,
      tollTOKEN: this.TOKEN * (1 - c)
    };
  }

  /** @internal */
  _poke(k: number, u: number, polRatio: number): ChickenBondDatum {
    const datum = this.peek(k, u, polRatio);
    this.data.push(datum);

    return datum;
  }

  get sTOKEN(): number {
    return this.data.length ? this.data[this.data.length - 1].sTOKEN : panic("Poke me first");
  }

  get tollTOKEN(): number {
    return this.data.length ? this.data[this.data.length - 1].tollTOKEN : panic("Poke me first");
  }
}
