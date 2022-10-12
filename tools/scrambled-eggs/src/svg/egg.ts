import {
  EggTraits,
  isLuminous,
  isMetallicColor,
  isRainbowColor,
  metallicColors,
  scales,
  solidShellColors
} from "../traits";

import { CommonArtworkParams } from "./common/types";
import { darkModeDefs, lightModeDefs } from "./common/defs";
import { darkModeBorder, darkModeCard, lightModeBorder, lightModeCard, text } from "./common/parts";

import {
  eggShellHighlightPath,
  scaleEggPath,
  scaleEggCastShadow,
  eggShellSelfShadowPath,
  eggShellPath
} from "./scaling/egg";

interface EggArtworkParams extends CommonArtworkParams, EggTraits {}

export const generateEggSVG = (params: EggArtworkParams) => {
  const { tokenID, cardColor, shellColor, size } = params;

  const scale = scales[size];
  const castShadowCoords = scaleEggCastShadow(scale).toString();
  const shellPathData = scaleEggPath(eggShellPath, scale).toString();
  const highlightPathData = scaleEggPath(eggShellHighlightPath, scale).toString();
  const selfShadowPathData = scaleEggPath(eggShellSelfShadowPath, scale).toString();

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
    ${isLuminous(shellColor) ? darkModeDefs(params) : lightModeDefs(params)}

    ${
      isRainbowColor(shellColor) || (isLuminous(shellColor) && isRainbowColor(cardColor))
        ? /*svg*/ `
            <!-- rainbow shell gradient -->
            <linearGradient id="cb-egg-${tokenID}-shell-rainbow-gradient" x1="39%" y1="59%" x2="62%" y2="35%" gradientUnits="userSpaceOnUse">
              <stop offset="0" stop-color="#3fa9f5"/>
              <stop offset="0.38" stop-color="#39b54a"/>
              <stop offset="0.82" stop-color="#fcee21"/>
              <stop offset="1" stop-color="#fbb03b"/>
            </linearGradient>
          `
        : ""
    }
  </defs>

  <g id="cb-egg-${tokenID}">
    ${isLuminous(shellColor) ? darkModeBorder(params) : lightModeBorder(params)}
    ${isLuminous(shellColor) ? darkModeCard(params) : lightModeCard(params)}

    <!-- shadow below egg -->
    ${
      isLuminous(shellColor)
        ? /*svg*/ `<ellipse style="mix-blend-mode: luminosity" fill="#0a102e" ${castShadowCoords} />`
        : /*svg*/ `<ellipse fill="#0a102e" ${castShadowCoords} />`
    }

    <!-- egg -->
    <g class="cb-egg">
      ${
        isRainbowColor(shellColor) || (isLuminous(shellColor) && isRainbowColor(cardColor))
          ? /*svg*/ `<path style="fill: url(#cb-egg-${tokenID}-shell-rainbow-gradient)" d="${shellPathData}" />`
          : isMetallicColor(shellColor)
          ? /*svg*/ `<path fill="${metallicColors[shellColor].solid}" d="${shellPathData}" />`
          : isLuminous(shellColor) && isMetallicColor(cardColor)
          ? /*svg*/ `<path fill="${metallicColors[cardColor].solid}" d="${shellPathData}" />`
          : isLuminous(shellColor)
          ? /*svg*/ `<path style="mix-blend-mode: luminosity" fill="#e5eff9" d="${shellPathData}" />`
          : /*svg*/ `<path fill="${solidShellColors[shellColor]}" d="${shellPathData}" />`
      }

      <path style="mix-blend-mode: soft-light" fill="#fff" d="${highlightPathData}"/>
      <path style="mix-blend-mode: soft-light" fill="#000" d="${selfShadowPathData}"/>
    </g>

    ${text("BOND AMOUNT", params)}
  </g>
</svg>
`;
};
