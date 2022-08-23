import {
  highlightPath,
  scaleEggPath,
  scaleCastShadow,
  selfShadowPath,
  shellPath
} from "./eggScaling";

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
const isCardGradient = (key: string): key is CardGradient => cardGradientSet.has(key);

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
const isMetallicColor = (key: string): key is MetallicColor => metallicColorSet.has(key);

export const rainbowColor = "rainbow";
type RainbowColor = typeof rainbowColor;
const isRainbowColor = (key: string): key is RainbowColor => key === rainbowColor;

export const luminous = "luminous";
type Luminous = typeof luminous;
const isLuminous = (key: string): key is Luminous => key === luminous;

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

export const eggScales = {
  tiny: 0.6,
  small: 0.8,
  normal: 1,
  big: 1.2
};

export type EggSize = keyof typeof eggScales;

export const eggSizes = Object.keys(eggScales) as EggSize[];

export interface EggArtworkAttributes {
  tokenID: number;
  borderColor: BorderColor;
  cardColor: CardColor;
  shellColor: ShellColor;
  eggSize: EggSize;
}

export const generateSVG = ({
  tokenID,
  borderColor,
  cardColor,
  shellColor,
  eggSize
}: EggArtworkAttributes) => {
  const eggScale = eggScales[eggSize];
  const castShadowCoords = scaleCastShadow(eggScale).toString();
  const shellPathData = scaleEggPath(shellPath, eggScale).toString();
  const highlightPathData = scaleEggPath(highlightPath, eggScale).toString();
  const selfShadowPathData = scaleEggPath(selfShadowPath, eggScale).toString();

  return /*svg*/ `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">
  <style>
    #cb-egg-${tokenID} .cb-egg path {
      animation: shake 3s infinite ease-out;
      transform-origin: 50%;
    }

    @keyframes shake {
      0% { transform: rotate(0deg); }
      65% { transform: rotate(0deg); }
      70% { transform: rotate(3deg); }
      75% { transform: rotate(0deg); }
      80% { transform: rotate(-3deg); }
      85% { transform: rotate(0deg); }
      90% { transform: rotate(3deg); }
      100% { transform: rotate(0deg); }
    }
  </style>

  <defs>
    <!-- diagonal card gradient -->
    ${
      isCardGradient(cardColor)
        ? /*svg*/ `
          <linearGradient id="cb-egg-${tokenID}-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="${cardGradients[cardColor][0]}"/>
            <stop offset="1" stop-color="${cardGradients[cardColor][1]}"/>
          </linearGradient>`
        : isMetallicColor(cardColor)
        ? /*svg*/ `
          <linearGradient id="cb-egg-${tokenID}-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="${metallicColors[cardColor].gradient[0]}"/>
            <stop offset="1" stop-color="${metallicColors[cardColor].gradient[1]}"/>
          </linearGradient>`
        : ""
    }

    <!-- black radial gradient (spotlight) -->
    ${
      isLuminous(shellColor)
        ? /*svg*/ `
          <radialGradient id="cb-egg-${tokenID}-card-radial-gradient" cx="50%" cy="45%" r="38%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-opacity="0"/>
            <stop offset="0.25" stop-opacity="0"/>
            <stop offset="1" stop-color="#000" stop-opacity="1"/>
          </radialGradient>`
        : ""
    }

    <!-- rainbow card gradient -->
    ${
      isRainbowColor(cardColor) || isRainbowColor(borderColor)
        ? /*svg*/ `
          <linearGradient id="cb-egg-${tokenID}-card-rainbow-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="#93278f"/>
            <stop offset="0.2" stop-color="#662d91"/>
            <stop offset="0.4" stop-color="#3395d4"/>
            <stop offset="0.5" stop-color="#39b54a"/>
            <stop offset="0.6" stop-color="#fcee21"/>
            <stop offset="0.8" stop-color="#fbb03b"/>
            <stop offset="1" stop-color="#ed1c24"/>
          </linearGradient>`
        : ""
    }

    <!-- rainbow shell gradient -->
    ${
      isRainbowColor(shellColor) || (isLuminous(shellColor) && isRainbowColor(cardColor))
        ? /*svg*/ `
          <linearGradient id="cb-egg-${tokenID}-shell-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="#3fa9f5"/>
            <stop offset="0.38" stop-color="#39b54a"/>
            <stop offset="0.82" stop-color="#fcee21"/>
            <stop offset="1" stop-color="#fbb03b"/>
          </linearGradient>`
        : ""
    }
  </defs>

  <g id="cb-egg-${tokenID}">
    <!-- border -->
    ${
      isLuminous(shellColor) && borderColor === "black"
        ? "" // We will use the black radial gradient as border (covering the entire card)
        : isRainbowColor(borderColor)
        ? /*svg*/ `<rect style="fill: url(#cb-egg-${tokenID}-card-rainbow-gradient)" width="100%" height="100%" rx="37.5"/>`
        : /*svg*/ `
          <rect
            fill="${
              isMetallicColor(borderColor)
                ? metallicColors[borderColor].solid
                : solidBorderColors[borderColor]
            }"
            width="750" height="1050" rx="37.5"
          />`
    }

    <!-- card colour -->
    ${
      isRainbowColor(cardColor)
        ? isRainbowColor(borderColor)
          ? /*svg*/ `<rect fill="#000" x="30" y="30" width="690" height="990" rx="37.5" opacity="0.05" />`
          : /*svg*/ `
            <rect x="30" y="30" width="690" height="990" rx="37.5" style="fill: url(#cb-egg-${tokenID}-card-rainbow-gradient)" />
            <rect fill="#000" x="30" y="30" width="690" height="990" rx="37.5" opacity="0.05" />`
        : isCardGradient(cardColor) || isMetallicColor(cardColor)
        ? /*svg*/ `<rect x="30" y="30" width="690" height="990" rx="37.5" style="fill: url(#cb-egg-${tokenID}-card-diagonal-gradient)" />`
        : /*svg*/ `
          <rect
            fill="${solidCardColors[cardColor]}"
            x="30" y="30" width="690" height="990" rx="37.5"
          />`
    }

    <!-- black radial gradient -->
    ${
      isLuminous(shellColor)
        ? borderColor === "black"
          ? /*svg*/ `
            <rect width="100%" height="100%" rx="37.5" style="mix-blend-mode: hard-light; fill: url(#cb-egg-${tokenID}-card-radial-gradient)"/>`
          : /*svg*/ `
            <rect x="30" y="30" width="690" height="990" rx="37.5" style="mix-blend-mode: hard-light; fill: url(#cb-egg-${tokenID}-card-radial-gradient)"/>`
        : ""
    }

    <!-- text -->
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="72px" font-weight="800" text-anchor="middle" x="50%" y="14%">LUSD</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="19%">ID: ${tokenID}</text>

    <!-- shadow below egg -->
    <ellipse
      ${isLuminous(shellColor) ? 'style="mix-blend-mode: luminosity"' : ""}
      fill="#0a102e"
      ${castShadowCoords}
    />

    <!-- egg -->
    <g class="cb-egg">
      ${
        isRainbowColor(shellColor) || (isLuminous(shellColor) && isRainbowColor(cardColor))
          ? /*svg*/ `
            <path
              style="fill: url(#cb-egg-${tokenID}-shell-rainbow-gradient)"
              fill="#fff1cb"
              d="${shellPathData}"
            />`
          : isMetallicColor(shellColor)
          ? /*svg*/ `
            <path
              fill="${metallicColors[shellColor].solid}"
              d="${shellPathData}"
            />`
          : isLuminous(shellColor) && isMetallicColor(cardColor)
          ? /*svg*/ `
            <path
              fill="${metallicColors[cardColor].solid}"
              d="${shellPathData}"
            />`
          : isLuminous(shellColor)
          ? /*svg*/ `
            <path
              style="mix-blend-mode: luminosity"
              fill="#e5eff9"
              d="${shellPathData}"
            />`
          : /*svg*/ `
            <path
              fill="${solidShellColors[shellColor]}"
              d="${shellPathData}"
            />`
      }

      <path style="mix-blend-mode: soft-light" fill="#fff" d="${highlightPathData}"/>
      <path style="mix-blend-mode: soft-light" fill="#000" d="${selfShadowPathData}"/>
    </g>

    <!-- text -->
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="40px" font-weight="800" text-anchor="middle" x="50%" y="72%">BOND AMOUNT</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="64px" font-weight="800" text-anchor="middle" x="50%" y="81%">1337</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="91%" opacity="0.6">JANUARY 1, 1970</text>
  </g>
</svg>
`;
};
