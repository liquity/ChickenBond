import { Pair, panic } from "../utils";

export interface ChickenBondDatum {
  k: number;
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

  private _sTOKEN?: number;
  private _tollTOKEN?: number;

  constructor(curve: ChickenBondCurve, k0: number, TOKEN: number) {
    this._curve = curve;
    this.k0 = k0;
    this.TOKEN = TOKEN;
  }

  /** @internal */
  _poke(k: number, u: number, polRatio: number): void {
    const y = this._curve(k - this.k0, u);
    const sTOKEN = (this._sTOKEN = (this.TOKEN / polRatio) * y);
    const tollTOKEN = (this._tollTOKEN = this.TOKEN * (1 - y));

    this.data.push({ k, sTOKEN, tollTOKEN });
  }

  get sTOKEN(): number {
    return this._sTOKEN ?? panic("Poke me first");
  }

  get tollTOKEN(): number {
    return this._tollTOKEN ?? panic("Poke me first");
  }
}
