import SvgPath from "svgpath";
import { round, viewBoxHeight, viewBoxWidth } from "./common";

export const eggShellPath = Object.freeze(
  new SvgPath(
    [
      "M239.76",
      "481.87c0",
      "75.6",
      "60.66",
      "136.88",
      "135.49",
      "136.88s135.49-61.28",
      "135.49-136.88S450.08",
      "294.75",
      "375.25",
      "294.75C304.56",
      "294.75",
      "239.76",
      "406.27",
      "239.76",
      "481.87Z"
    ].join(" ")
  )
);

export const eggShellHighlightPath = Object.freeze(
  new SvgPath(
    [
      "M298.26",
      "367.33c-10",
      "22.65-9.13",
      "49.22",
      "5.42",
      "60.19",
      "16.26",
      "12.25",
      "39.81",
      "15",
      "61.63-5.22",
      "20.95-19.43",
      "39.13-73.24",
      "2.07-92.5C347.08",
      "319.25",
      "309.31",
      "342.25",
      "298.26",
      "367.33Z"
    ].join(" ")
  )
);

export const eggShellSelfShadowPath = Object.freeze(
  new SvgPath(
    [
      "M443.61",
      "326.7c19.9",
      "34.86",
      "31.91",
      "75.58",
      "31.91",
      "109.2",
      "0",
      "75.6-60.67",
      "136.88-135.5",
      "136.88a134.08",
      "134.08",
      "0",
      "0",
      "1-87.53-32.41C274.2",
      "586.72",
      "320.9",
      "618.78",
      "375",
      "618.78c74.83",
      "0",
      "135.5-61.28",
      "135.5-136.88C510.52",
      "431.58",
      "483.64",
      "365.37",
      "443.61",
      "326.7Z"
    ].join(" ")
  )
);

const transformOriginX = 0.5 * viewBoxWidth;
const transformOriginY = 0.45 * viewBoxHeight;

export const scaleEggPath = (path: typeof SvgPath, s: number) =>
  SvgPath.from(path)
    .translate(-transformOriginX, -transformOriginY)
    .scale(s)
    .translate(transformOriginX, transformOriginY)
    .round(2);

export const scaleEggCastShadow = (s: number) => ({
  cx: (375 - transformOriginX) * s + transformOriginX,
  cy: (618.75 - transformOriginY) * s + transformOriginY,
  rx: 100 * s,
  ry: 19 * s,

  toString() {
    return [
      `cx="${round(this.cx)}"`,
      `cy="${round(this.cy)}"`,
      `rx="${round(this.rx)}"`,
      `ry="${round(this.ry)}"`
    ].join(" ");
  }
});
