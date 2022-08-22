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

export type CardColor = SolidCardColor | CardGradient | MetallicColor | RainbowColor;
export type ShellColor = SolidShellColor | MetallicColor | RainbowColor | Luminous;

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
] as CardColor[];

export interface EggArtworkAttributes {
  cardColor: CardColor;
  shellColor: ShellColor;
}

export const generateSVG = (attributes: EggArtworkAttributes) => /*svg*/ `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">
  <style>
    #cb-egg-1 .cb-egg {
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
    ${
      isCardGradient(attributes.cardColor)
        ? /*svg*/ `
          <!-- diagonal card gradient -->
          <linearGradient id="cb-egg-1-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="${cardGradients[attributes.cardColor][0]}"/>
            <stop offset="1" stop-color="${cardGradients[attributes.cardColor][1]}"/>
          </linearGradient>`
        : isMetallicColor(attributes.cardColor)
        ? /*svg*/ `
          <!-- diagonal card gradient -->
          <linearGradient id="cb-egg-1-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="${metallicColors[attributes.cardColor].gradient[0]}"/>
            <stop offset="1" stop-color="${metallicColors[attributes.cardColor].gradient[1]}"/>
          </linearGradient>`
        : ""
    }

    ${
      isLuminous(attributes.shellColor)
        ? /*svg*/ `
          <!-- black radial gradient (spotlight) -->
          <radialGradient id="cb-egg-1-card-radial-gradient" cx="50%" cy="45%" r="38%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-opacity="0"/>
            <stop offset="0.25" stop-opacity="0"/>
            <stop offset="1" stop-color="#000" stop-opacity="1"/> 
          </radialGradient>`
        : ""
    }

    ${
      isRainbowColor(attributes.cardColor)
        ? /*svg*/ `
          <!-- rainbow card gradient -->
          <linearGradient id="cb-egg-1-card-rainbow-gradient" y1="100%" gradientUnits="userSpaceOnUse">
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

    ${
      isRainbowColor(attributes.shellColor) ||
      (isLuminous(attributes.shellColor) && isRainbowColor(attributes.cardColor))
        ? /*svg*/ `
          <!-- rainbow shell gradient -->
          <linearGradient id="cb-egg-1-shell-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="#3fa9f5"/>
            <stop offset="0.38" stop-color="#39b54a"/>
            <stop offset="0.82" stop-color="#fcee21"/>
            <stop offset="1" stop-color="#fbb03b"/>
          </linearGradient>`
        : ""
    }
  </defs>

  <g id="cb-egg-1">
    <!-- border -->
    ${
      isRainbowColor(attributes.cardColor)
        ? /*svg*/ `<rect style="fill: url(#cb-egg-1-card-rainbow-gradient)" width="100%" height="100%" rx="37.5"/>`
        : !isLuminous(attributes.shellColor)
        ? /*svg*/ `
          <rect
            fill="${
              isMetallicColor(attributes.cardColor)
                ? metallicColors[attributes.cardColor].solid
                : "#fff"
            }"
            width="750" height="1050" rx="37.5"
          />`
        : ""
    }

    <!-- card colour -->
    ${
      isRainbowColor(attributes.cardColor)
        ? /*svg*/ `<rect fill="#000" x="30" y="30" width="690" height="990" rx="37.5" opacity="0.05" />`
        : isCardGradient(attributes.cardColor) || isMetallicColor(attributes.cardColor)
        ? /*svg*/ `<rect x="30" y="30" width="690" height="990" rx="37.5" style="fill: url(#cb-egg-1-card-diagonal-gradient)" />`
        : /*svg*/ `
          <rect
            fill="${solidCardColors[attributes.cardColor]}"
            x="30" y="30" width="690" height="990" rx="37.5"
          />`
    }

    ${
      isLuminous(attributes.shellColor)
        ? /*svg*/ `
          <!-- black radial gradient -->
          <rect width="750" height="1050" rx="37.5" style="mix-blend-mode: hard-light; fill: url(#cb-egg-1-card-radial-gradient)"/>`
        : ""
    }

    <!-- text -->
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="72px" font-weight="800" text-anchor="middle" x="50%" y="14%">LUSD</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="19%">ID: 1</text>

    <!-- shadow below egg -->
    <ellipse
      ${isLuminous(attributes.shellColor) ? 'style="mix-blend-mode: luminosity"' : ""}
      fill="#0a102e"
      cx="375" cy="618.75" rx="100" ry="19"
    />

    <!-- egg -->
    ${
      isRainbowColor(attributes.shellColor) ||
      (isLuminous(attributes.shellColor) && isRainbowColor(attributes.cardColor))
        ? /*svg*/ `
          <path
            style="fill: url(#cb-egg-1-shell-rainbow-gradient)"
            fill="#fff1cb"
            d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"
          />`
        : isMetallicColor(attributes.shellColor)
        ? /*svg*/ `
          <path
            fill="${metallicColors[attributes.shellColor].solid}"
            d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"
          />`
        : isLuminous(attributes.shellColor) && isMetallicColor(attributes.cardColor)
        ? /*svg*/ `
          <path
            fill="${metallicColors[attributes.cardColor].solid}"
            d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"
          />`
        : isLuminous(attributes.shellColor)
        ? /*svg*/ `
          <path
            style="mix-blend-mode: luminosity"
            fill="#e5eff9"
            d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"
          />`
        : /*svg*/ `
          <path
            fill="${solidShellColors[attributes.shellColor]}"
            d="M239.76,481.87c0,75.6,60.66,136.88,135.49,136.88s135.49-61.28,135.49-136.88S450.08,294.75,375.25,294.75C304.56,294.75,239.76,406.27,239.76,481.87Z"
          />`
    }

    <!-- egg highlight -->
    <path style="mix-blend-mode: soft-light" fill="#fff" d="M298.26,367.33c-10,22.65-9.13,49.22,5.42,60.19,16.26,12.25,39.81,15,61.63-5.22,20.95-19.43,39.13-73.24,2.07-92.5C347.08,319.25,309.31,342.25,298.26,367.33Z"/>
    <path style="mix-blend-mode: soft-light" fill="#000" d="M443.61,326.7c19.9,34.86,31.91,75.58,31.91,109.2,0,75.6-60.67,136.88-135.5,136.88a134.08,134.08,0,0,1-87.53-32.41C274.2,586.72,320.9,618.78,375,618.78c74.83,0,135.5-61.28,135.5-136.88C510.52,431.58,483.64,365.37,443.61,326.7Z"/>

    <!-- text -->
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="40px" font-weight="800" text-anchor="middle" x="50%" y="72%">BOND AMOUNT</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="64px" font-weight="800" text-anchor="middle" x="50%" y="81%">1337</text>
    <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="91%" opacity="0.6">JANUARY 1, 1970</text>
  </g>
</svg>
`;
