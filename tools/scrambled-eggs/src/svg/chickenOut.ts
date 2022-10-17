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

const globalScale = 1.1;
const sizeRange = Object.values(scales).map(s => s * globalScale);

export const generateChickenOutSVG = (params: ChickenOutArtworkParams) => {
  const { tokenID, shellColor, chickenColor, size } = params;

  const darkMode = isLuminous(shellColor) || isLuminous(chickenColor);
  const scale = globalScale * scales[size];

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
    ${chickenOutAnimations.instantiate([scale], params)}
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
  </defs>

  <g id="co-chicken-${tokenID}">
    ${darkMode ? darkModeBorder(params) : lightModeBorder(params)}
    ${darkMode ? darkModeCard(params) : lightModeCard(params)}

    <line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="173" y1="460" x2="227" y2="460"/>
    <line style="fill: none; mix-blend-mode: soft-light; stroke: #333; stroke-linecap: round; stroke-miterlimit: 10; stroke-width: 6px" x1="149" y1="500" x2="203" y2="500"/>

    ${chickenOutShadow.instantiate([scale], {})}

    <g class="co-chicken">
      ${chickenOutLeftLeg.instantiate([scale], {})}
      ${chickenOutRightLeg.instantiate([scale], {})}
      ${chickenOutBeak.instantiate([scale], {})}
      ${chickenOutChicken.instantiate([scale], { style: chickenStyle })}
      ${chickenOutEye.instantiate([scale], {})}
      ${chickenOutShell.instantiate([scale], { style: shellStyle })}
    </g>

    ${text("CHICKEN OUT", params)}
  </g>
</svg>
`;
};

export const chickenOutSolidity = () =>
  `
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./CommonData.sol";
import "./ChickenOutData.sol";

${chickenOutAnimations.solidity(
  "ChickenOutAnimations",
  "getSVGAnimations(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  { tokenID: "_commonData.tokenIDString" }
)}

${chickenOutShadow.solidity(
  "ChickenOutShadow",
  "getSVGShadow(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  {}
)}

${chickenOutLeftLeg.solidity(
  "ChickenOutLeftLeg",
  "getSVGLeftLeg(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  {}
)}

${chickenOutRightLeg.solidity(
  "ChickenOutRightLeg",
  "getSVGRightLeg(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  {}
)}

${chickenOutBeak.solidity(
  "ChickenOutBeak",
  "getSVGBeak(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  {}
)}

${chickenOutChicken.solidity(
  "ChickenOutChicken",
  "getSVGChicken(CommonData calldata _commonData, ChickenOutData calldata _chickenOutData)",
  [["uint256(_commonData.size)", sizeRange]],
  { style: "_chickenOutData.chickenStyle" }
)}

${chickenOutEye.solidity(
  "ChickenOutEye",
  "getSVGEye(CommonData calldata _commonData)",
  [["uint256(_commonData.size)", sizeRange]],
  {}
)}

${chickenOutShell.solidity(
  "ChickenOutShell",
  "getSVGShell(CommonData calldata _commonData, ChickenOutData calldata _chickenOutData)",
  [["uint256(_commonData.size)", sizeRange]],
  { style: "_chickenOutData.shellStyle" }
)}

contract ChickenOutGenerated1 is
  ChickenOutAnimations,
  ChickenOutShadow,
  ChickenOutLeftLeg,
  ChickenOutRightLeg,
  ChickenOutBeak,
  ChickenOutChicken,
  ChickenOutEye,
  ChickenOutShell
{}

contract ChickenOutGenerated {
    ChickenOutGenerated1 public immutable g1;

    constructor(ChickenOutGenerated1 _g1) {
        g1 = _g1;
    }

    function _getSVGAnimations(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGAnimations(_commonData);
    }

    function _getSVGShadow(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGShadow(_commonData);
    }

    function _getSVGLeftLeg(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGLeftLeg(_commonData);
    }

    function _getSVGRightLeg(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGRightLeg(_commonData);
    }

    function _getSVGBeak(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGBeak(_commonData);
    }

    function _getSVGChicken(CommonData memory _commonData, ChickenOutData memory _chickenOutData) internal view returns (bytes memory) {
        return g1.getSVGChicken(_commonData, _chickenOutData);
    }

    function _getSVGEye(CommonData memory _commonData) internal view returns (bytes memory) {
        return g1.getSVGEye(_commonData);
    }

    function _getSVGShell(CommonData memory _commonData, ChickenOutData memory _chickenOutData) internal view returns (bytes memory) {
        return g1.getSVGShell(_commonData, _chickenOutData);
    }
}
`.trimStart();
