import {
  ChickenInTraits,
  isLuminous,
  isMetallicColor,
  isRainbowColor,
  metallicColors,
  scales,
  solidShellColors
} from "../traits";

import { CommonArtworkParams } from "./common/types";
import { darkModeDefs, lightModeDefs } from "./common/defs";

import {
  borderFill,
  darkModeBorder,
  darkModeCard,
  lightModeBorder,
  lightModeCard,
  text
} from "./common/parts";

import {
  chickenInAnimations,
  chickenInBeak,
  chickenInBody,
  chickenInCheek,
  chickenInComb,
  chickenInEye,
  chickenInLegs,
  chickenInLQTYBand,
  chickenInShadow,
  chickenInTail,
  chickenInWattle,
  chickenInWing
} from "./scaling/chickenIn";

interface ChickenInArtworkParams extends CommonArtworkParams, ChickenInTraits {}

export const generateChickenInSVG = (params: ChickenInArtworkParams) => {
  const {
    tokenID,
    borderColor,
    cardColor,
    chickenColor,
    comb,
    beak,
    tail,
    wing,
    size,
    trove,
    llama,
    lqtyBand
  } = params;

  const darkMode = isLuminous(chickenColor);
  const scale = 0.9 * scales[size];

  const chickenFill =
    isRainbowColor(chickenColor) || (isLuminous(chickenColor) && isRainbowColor(cardColor))
      ? `url(#ci-chicken-${tokenID}-chicken-rainbow-gradient)`
      : isLuminous(chickenColor) && isMetallicColor(cardColor)
      ? metallicColors[cardColor].solid
      : isMetallicColor(chickenColor)
      ? metallicColors[chickenColor].solid
      : isLuminous(chickenColor)
      ? "#e5eff9"
      : solidShellColors[chickenColor];

  const chickenStyle =
    `fill: ${chickenFill}` +
    (isLuminous(chickenColor) && !isRainbowColor(cardColor) && !isMetallicColor(cardColor)
      ? "; mix-blend-mode: luminosity"
      : "");

  const legStyle = isLuminous(chickenColor) ? chickenStyle : "fill: #21130a";
  const cheekStyle = isRainbowColor(chickenColor) ? "fill: #fcee21" : chickenStyle;

  const bodyShadeStyle =
    "fill: " +
    (isRainbowColor(chickenColor) || (isLuminous(chickenColor) && isRainbowColor(cardColor))
      ? "#333"
      : chickenColor === "bronze" || chickenColor === "silver"
      ? "#333"
      : "#000") +
    "; mix-blend-mode: soft-light";

  const wingShadeStyle =
    "fill: " +
    (isRainbowColor(chickenColor) || (isLuminous(chickenColor) && isRainbowColor(cardColor))
      ? wing === 1
        ? "#000"
        : "#333"
      : wing === 1
      ? "#fff"
      : "#ccc") +
    "; mix-blend-mode: soft-light";

  const wingTipShadeStyle =
    isRainbowColor(chickenColor) || (isLuminous(chickenColor) && isRainbowColor(cardColor))
      ? "fill: #ccc; mix-blend-mode: soft-light"
      : wingShadeStyle;

  const caruncleStyle =
    isLuminous(chickenColor) || isRainbowColor(chickenColor) || isMetallicColor(chickenColor)
      ? chickenStyle
      : "fill: #eb5838";

  const beakStyle =
    isLuminous(chickenColor) || isMetallicColor(chickenColor) ? chickenStyle : "fill: #f69222";

  return /*svg*/ `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">
  <style>
    ${chickenInAnimations(tokenID, scale)}
  </style>

  <defs>
    ${darkMode ? darkModeDefs(params) : lightModeDefs(params)}

    ${
      isRainbowColor(chickenColor)
        ? /*svg*/ `
            <!-- chicken rainbow gradient -->
            <linearGradient id="ci-chicken-${tokenID}-chicken-rainbow-gradient" y1="100%" gradientUnits="objectBoundingBox">
              <stop offset="0" stop-color="#93278f"/>
              <stop offset="0.2" stop-color="#662d91"/>
              <stop offset="0.4" stop-color="#3395d4"/>
              <stop offset="0.5" stop-color="#39b54a"/>
              <stop offset="0.6" stop-color="#fcee21"/>
              <stop offset="0.8" stop-color="#fbb03b"/>
              <stop offset="1" stop-color="#ed1c24"/>
            </linearGradient>
          `
        : isLuminous(chickenColor) && isRainbowColor(cardColor)
        ? /*svg*/ `
            <!-- chicken rainbow gradient -->
            <linearGradient id="ci-chicken-${tokenID}-chicken-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">
              <stop offset="0" stop-color="#3fa9f5"/>
              <stop offset="0.38" stop-color="#39b54a"/>
              <stop offset="0.82" stop-color="#fcee21"/>
              <stop offset="1" stop-color="#fbb03b"/>
            </linearGradient>
          `
        : ""
    }
  </defs>

  <g id="ci-chicken-${tokenID}">
    ${darkMode ? darkModeBorder(params) : lightModeBorder(params)}
    ${darkMode ? darkModeCard(params) : lightModeCard(params)}

    ${chickenInShadow(scale)}
    ${chickenInLegs(legStyle, scale)}

    <g class="ci-breath">
      ${chickenInComb(comb, caruncleStyle, scale)}
      ${isMetallicColor(chickenColor) ? chickenInComb(comb, bodyShadeStyle, scale) : ""}
      ${
        chickenColor === "bronze" || chickenColor === "silver"
          ? chickenInComb(comb, bodyShadeStyle, scale)
          : ""
      }

      ${chickenInBeak(beak, beakStyle, scale)}
      ${isMetallicColor(chickenColor) ? chickenInBeak(beak, bodyShadeStyle, scale) : ""}
      ${
        chickenColor === "bronze" || chickenColor === "silver"
          ? chickenInBeak(beak, bodyShadeStyle, scale)
          : ""
      }

      ${chickenInWattle(caruncleStyle, scale)}
      ${isMetallicColor(chickenColor) ? chickenInWattle(bodyShadeStyle, scale) : ""}
      ${
        chickenColor === "bronze" || chickenColor === "silver"
          ? chickenInWattle(bodyShadeStyle, scale)
          : ""
      }

      ${chickenInBody(chickenStyle, bodyShadeStyle, scale)}
      ${chickenInEye(scale)}
      ${chickenInCheek(cheekStyle, scale)}

      ${chickenInTail(tail, chickenStyle, scale)}
      ${chickenInTail(tail, bodyShadeStyle, scale)}
      ${
        chickenColor === "bronze" || chickenColor === "silver"
          ? chickenInTail(tail, bodyShadeStyle, scale)
          : ""
      }
    </g>

    <g class="ci-wing">
      ${chickenInWing(wing, chickenStyle, wingShadeStyle, wingTipShadeStyle, scale)}
    </g>
  
    ${lqtyBand ? chickenInLQTYBand(scale) : ""}

    ${
      trove
        ? /*svg*/ `
            <rect style="fill: ${borderFill(params)}" y="932" width="118" height="118" rx="37.5"/>
            <rect style="fill: #a55529" x="36.28" y="963.98" width="54.44" height="19.21" rx="9.61"/>
            <rect style="fill: #843b17" x="36.28" y="983.19" width="54.44" height="19.21" rx="9.61"/>
            <rect style="fill: gold" x="36.28" y="983.19" width="7.69" height="20.49" rx="3.84"/>
            <rect style="fill: gold" x="83.03" y="983.19" width="7.69" height="20.49" rx="3.84"/>
            <rect style="fill: #000; mix-blend-mode: soft-light" x="36.28" y="983.19" width="7.69" height="20.49" rx="3.84"/>
            <rect style="fill: #000; mix-blend-mode: soft-light" x="83.03" y="983.19" width="7.69" height="20.49" rx="3.84"/>
            <path style="fill: gold" d="M90.61,980.24a3.8,3.8,0,0,0,.11-.89V966.54a3.85,3.85,0,0,0-7.69,0v12.81H70.14a4,4,0,0,0-3.93-3.2H60.79a4,4,0,0,0-3.93,3.2H44V966.54a3.85,3.85,0,0,0-7.69,0v12.81a3.8,3.8,0,0,0,.11.89A3.84,3.84,0,0,0,38.84,987h18a4,4,0,0,0,3.93,3.21h5.42A4,4,0,0,0,70.14,987h18a3.84,3.84,0,0,0,2.45-6.79Z"/>
            <ellipse style="fill: #000" cx="63.45" cy="981.34" rx="1.94" ry="1.96"/>
            <path style="fill: #000" d="M60.87,986.07l1.92-4.68a.72.72,0,0,1,1.33,0L66,986.07a.72.72,0,0,1-.66,1H61.53A.72.72,0,0,1,60.87,986.07Z"/>
          `
        : ""
    }

    ${
      llama
        ? /*svg*/ `
            <rect
              style="fill: ${borderFill(params)}"
              x="632" y="932" width="118" height="118" rx="37.5"
            />

            <path
              style="fill: ${borderColor === "bronze" ? "#a55529" : "#cd7f32"}"
              d="M710.26,979.9c-.45-2.6-2.28.21-4.93,2.39a5.57,5.57,0,0,0-1.3-.15H678.15V956.22a12.7,12.7,0,0,1-7.28-2.62,2.62,2.62,0,0,0-2.62,2.62v2.08a6.5,6.5,0,0,0-5.82,6.37h-2.81a3,3,0,0,0-3,3v1.89A4.4,4.4,0,0,0,661,974h1.41v37.16a1.86,1.86,0,0,0,1.86,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h2.91v6.29a1.85,1.85,0,0,0,1.85,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h8.74v6.29a1.85,1.85,0,0,0,1.85,1.86h4.44a1.86,1.86,0,0,0,1.86-1.86v-6.29h2.91v6.29a1.86,1.86,0,0,0,1.86,1.86h4.44a1.85,1.85,0,0,0,1.85-1.86V987.7c0-.12,0-.23,0-.34A12.13,12.13,0,0,0,710.26,979.9Z"
            />

            <path style="fill: #fff;mix-blend-mode: soft-light" d="M703.19,982.14h-25a12.52,12.52,0,0,0,25,0Z"/>
            <path style="fill: #fff;mix-blend-mode: soft-light" d="M699.22,982.14H682.53a8.35,8.35,0,0,0,16.69,0Z"/>
            <path style="fill: #fff;mix-blend-mode: soft-light" d="M695.05,982.14H686.7a4.18,4.18,0,0,0,8.35,0Z"/>
            <circle cx="669.7" cy="965.54" r="2.33"/>
          `
        : ""
    }

    ${text("CHICKEN IN", params)}
  </g>
</svg>
`;
};
