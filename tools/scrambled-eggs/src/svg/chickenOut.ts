import {
  ChickenOutTraits,
  isLuminous,
  isMetallicColor,
  isRainbowColor,
  metallicColors,
  scales,
  ShellColor,
  solidShellColors
} from "../traits";

import { CommonArtworkParams } from "./common/types";
import { darkModeDefs, lightModeDefs } from "./common/defs";
import { darkModeBorder, darkModeCard, lightModeBorder, lightModeCard, text } from "./common/parts";

import {
  chickenOutAnimations,
  chickenOutBeak,
  chickenOutChicken,
  chickenOutEye,
  chickenOutLeftLeg,
  chickenOutRightLeg,
  chickenOutShadow,
  chickenOutShell
} from "./scaling/chickenOut";

interface ChickenOutArtworkParams extends CommonArtworkParams, ChickenOutTraits {}

export const generateChickenOutSVG = (params: ChickenOutArtworkParams) => {
  const { tokenID, shellColor, chickenColor, size } = params;

  const darkMode = isLuminous(shellColor) || isLuminous(chickenColor);
  const scale = 1.1 * scales[size];

  const getFill = (color: ShellColor) =>
    isRainbowColor(color)
      ? `url(#co-chicken-${tokenID}-object-rainbow-gradient)`
      : isMetallicColor(color)
      ? metallicColors[color].solid
      : isLuminous(color)
      ? "#e5eff9"
      : solidShellColors[color];

  const chickenFill = getFill(chickenColor);
  const shellFill = getFill(shellColor);

  const chickenStyle =
    `fill: ${chickenFill}` + (isLuminous(chickenColor) ? "; mix-blend-mode: luminosity" : "");

  const shellStyle =
    `fill: ${shellFill}` + (isLuminous(shellColor) ? "; mix-blend-mode: luminosity" : "");

  return /*svg*/ `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 750 1050">
  <style>
    ${chickenOutAnimations(tokenID, scale)}
  </style>

  <defs>
    ${darkMode ? darkModeDefs(params) : lightModeDefs(params)}

    ${
      isRainbowColor(shellColor) || isRainbowColor(chickenColor)
        ? /*svg*/ `
            <!-- rainbow shell gradient -->
            <linearGradient id="co-chicken-${tokenID}-object-rainbow-gradient" y1="100%" gradientUnits="objectBoundingBox">
              <stop offset="0" stop-color="#93278f"/>
              <stop offset="0.2" stop-color="#662d91"/>
              <stop offset="0.4" stop-color="#3395d4"/>
              <stop offset="0.5" stop-color="#39b54a"/>
              <stop offset="0.6" stop-color="#fcee21"/>
              <stop offset="0.8" stop-color="#fbb03b"/>
              <stop offset="1" stop-color="#ed1c24"/>
            </linearGradient>
          `
        : ""
    }

    ${
      isRainbowColor(chickenColor)
        ? /*svg*/ `
            <!-- rainbow shell gradient -->
            <linearGradient id="co-chicken-${tokenID}-chicken-rainbow-gradient" x1="41%" y1="53%" x2="59%" y2="35%" gradientUnits="userSpaceOnUse">
              <stop offset="0" stop-color="#93278f"/>
              <stop offset="0.2" stop-color="#662d91"/>
              <stop offset="0.4" stop-color="#3395d4"/>
              <stop offset="0.5" stop-color="#39b54a"/>
              <stop offset="0.6" stop-color="#fcee21"/>
              <stop offset="0.8" stop-color="#fbb03b"/>
              <stop offset="1" stop-color="#ed1c24"/>
            </linearGradient>
            `
        : ""
    }
  </defs>

  <g id="co-chicken-${tokenID}">
    ${darkMode ? darkModeBorder(params) : lightModeBorder(params)}
    ${darkMode ? darkModeCard(params) : lightModeCard(params)}

    <line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="173" y1="460" x2="227" y2="460"/>
    <line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="149" y1="500" x2="203" y2="500"/>

    ${chickenOutShadow(scale)}

    <g class="co-chicken">
      <g class="co-left-leg">
        ${chickenOutLeftLeg("#352d20", scale)}
      </g>

      <g class="co-right-leg">
        ${chickenOutRightLeg("#352d20", scale)}
      </g>

      ${chickenOutBeak("#f69222", scale)}
      ${chickenOutChicken(chickenStyle, scale)}
      ${chickenOutEye(scale)}
      ${chickenOutShell(shellStyle, scale)}
    </g>

    ${text("CHICKEN OUT", params)}
  </g>
</svg>
`;
};
