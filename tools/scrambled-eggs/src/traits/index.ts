export const solidCardColors = {
  red: "#ea394e",
  green: "#5caa4b",
  blue: "#008bf7",
  purple: "#9d34e8",
  pink: "#e54cae"
};

export type SolidCardColor = keyof typeof solidCardColors;
// const solidCardColorSet = new Set(Object.keys(solidCardColors));
// const isSolidCardColor = (key: string): key is SolidCardColor => solidCardColorSet.has(key);

export const cardGradients = {
  "yellow-pink": ["#ffd200", "#ff0087"] as [string, string],
  "blue-green": ["#008bf7", "#58b448"] as [string, string],
  "pink-blue": ["#f900bd", "#00a7f6"] as [string, string],
  "red-purple": ["#ea394e", "#9d34e8"] as [string, string]
};

export type CardGradient = keyof typeof cardGradients;
const cardGradientSet = new Set(Object.keys(cardGradients));
export const isCardGradient = (key: string): key is CardGradient => cardGradientSet.has(key);

export const solidShellColors = {
  "off-white": "#fff1cb",
  "light blue": "#e5eff9",
  "darker blue": "#aedfe2",
  "lighter orange": "#f6dac9",
  "light orange": "#f8d1b2",
  "darker orange": "#fcba92",
  "light green": "#c5e8d6",
  "darker green": "#e5daaa"
};

export type SolidShellColor = keyof typeof solidShellColors;
// const solidShellColorSet = new Set(Object.keys(solidShellColors));
// const isSolidShellColor = (key: string): key is SolidShellColor => solidShellColorSet.has(key);

export const metallicColors = {
  bronze: { solid: "#cd7f32", gradient: ["#804a00", "#cd7b26"] as [string, string] },
  silver: { solid: "#c0c0c0", gradient: ["#71706e", "#b6b6b6"] as [string, string] },
  gold: { solid: "#ffd700", gradient: ["#aa6c39", "#ffae00"] as [string, string] }
};

export type MetallicColor = keyof typeof metallicColors;
const metallicColorSet = new Set(Object.keys(metallicColors));
export const isMetallicColor = (key: string): key is MetallicColor => metallicColorSet.has(key);

export const rainbowColor = "rainbow";
export type RainbowColor = typeof rainbowColor;
export const isRainbowColor = (key: string): key is RainbowColor => key === rainbowColor;

export const luminous = "luminous";
export type Luminous = typeof luminous;
export const isLuminous = (key: string): key is Luminous => key === luminous;

export const solidBorderColors = {
  white: "#fff",
  black: "#000"
};

export type SolidBorderColor = keyof typeof solidBorderColors;
// const solidBorderColorSet = new Set(Object.keys(solidBorderColors));
// const isSolidBorderColor = (key: string): key is SolidBorderColor => solidBorderColorSet.has(key);

export type CardColor = SolidCardColor | CardGradient | MetallicColor | RainbowColor;
export type ShellColor = SolidShellColor | MetallicColor | RainbowColor | Luminous;
export type BorderColor = SolidBorderColor | MetallicColor | RainbowColor;

export const cardColors = [
  ...Object.keys(solidCardColors),
  ...Object.keys(cardGradients),
  ...Object.keys(metallicColors),
  rainbowColor
] as CardColor[];

export const shellColors = [
  ...Object.keys(solidShellColors),
  ...Object.keys(metallicColors),
  rainbowColor,
  luminous
] as ShellColor[];

export const borderColors = [
  ...Object.keys(solidBorderColors),
  ...Object.keys(metallicColors),
  rainbowColor
] as BorderColor[];

export const scales = {
  tiny: 0.6,
  small: 0.8,
  normal: 1,
  big: 1.2
};

export type Size = keyof typeof scales;
export const sizes = Object.keys(scales) as Size[];

export const statuses = ["active" as const, "chickened in" as const, "chickened out" as const];
export type Status = typeof statuses extends (infer T)[] ? T : never;

export const combs = [...new Array(9).keys()].map(i => i + 1);
export const beaks = [...new Array(4).keys()].map(i => i + 1);
export const tails = [...new Array(9).keys()].map(i => i + 1);
export const wings = [...new Array(3).keys()].map(i => i + 1);

export interface CommonTraits {
  borderColor: BorderColor;
  cardColor: CardColor;
  size: Size;
}

export interface EggTraits extends CommonTraits {
  shellColor: ShellColor;
}

export interface ChickenOutTraits extends CommonTraits {
  shellColor: ShellColor;
  chickenColor: ShellColor;
}

export interface ChickenInTraits extends CommonTraits {
  chickenColor: ShellColor;
  comb: number;
  beak: number;
  tail: number;
  wing: number;
  trove: boolean;
  llama: boolean;
  lqtyBand: boolean;
}

export interface Traits extends EggTraits, ChickenOutTraits, ChickenInTraits {
  status: Status;
}

export const defaultTraits: Traits = {
  status: "active",
  size: "normal",
  borderColor: "white",
  cardColor: "blue",
  shellColor: "off-white",
  chickenColor: "off-white",
  comb: 1,
  beak: 1,
  tail: 1,
  wing: 1,
  trove: false,
  llama: false,
  lqtyBand: false
};

const randInt = (max: number) => Math.floor(max * Math.random());
const randElem = <T extends unknown>(arr: T[]): T => arr[randInt(arr.length)];

const bools = [false, true];

export const randomTraits = (): Omit<Traits, "status"> => ({
  size: randElem(sizes),
  borderColor: randElem(borderColors),
  cardColor: randElem(cardColors),
  shellColor: randElem(shellColors),
  chickenColor: randElem(shellColors),
  comb: randElem(combs),
  beak: randElem(beaks),
  tail: randElem(tails),
  wing: randElem(wings),
  trove: randElem(bools),
  llama: randElem(bools),
  lqtyBand: randElem(bools)
});
