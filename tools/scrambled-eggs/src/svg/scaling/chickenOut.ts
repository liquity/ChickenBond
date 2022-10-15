import SvgPath from "svgpath";
import { round, roundDigits, template, viewBoxHeight, viewBoxWidth } from "./common";

const transformOriginX = 0.5 * viewBoxWidth;
const transformOriginY = 0.55 * viewBoxHeight;

const scaleX = (x: number) => (s: number) => round((x - transformOriginX) * s + transformOriginX);
const scaleY = (y: number) => (s: number) => round((y - transformOriginY) * s + transformOriginY);
const mul = (x: number) => (s: number) => round(x * s);

const tokenID = "tokenID";
const style = "style";

export const chickenOutAnimations = template<[scale: number], { tokenID: number }>/*css*/ `
  #co-chicken-${tokenID} .co-chicken g,
  #co-chicken-${tokenID} .co-chicken path,
  #co-chicken-${tokenID} .co-chicken circle {
    animation: co-run 0.3s infinite ease-in-out alternate;
  }

  #co-chicken-${tokenID} .co-left-leg path {
    animation: co-left-leg 0.3s infinite ease-in-out alternate;
    transform-origin: ${scaleX(420)}px ${scaleY(525)}px;
  }

  #co-chicken-${tokenID} .co-right-leg path {
    animation: co-right-leg 0.3s infinite ease-in-out alternate;
    transform-origin: ${scaleX(320)}px ${scaleY(525)}px;
  }

  #co-chicken-${tokenID} .co-shadow {
    animation: co-shadow 0.3s infinite ease-in-out alternate;
    transform-origin: ${scaleX(375)}px ${scaleY(636)}px;
  }

  @keyframes co-run {
    10% { transform: translateY(0); }
    100% { transform: translateY(${mul(88)}px); }
  }

  @keyframes co-left-leg {
    20% { transform: rotate(-0deg); }
    100% { transform: rotate(-75deg) translateX(${mul(120)}px); }
  }

  @keyframes co-right-leg {
    0% { transform: rotate(5deg); }
    20% { transform: rotate(5deg); }
    100% { transform: rotate(70deg) translateX(${mul(-120)}px); }
  }

  @keyframes co-shadow {
    0% { transform: scale(60%); }
    100% { transform: scale(100%); }
  }
`;

const scaleEllipseCoords = (cx: number, cy: number, rx: number, ry: number) => (s: number) => ({
  cx: scaleX(cx)(s),
  cy: scaleY(cy)(s),
  rx: mul(rx)(s),
  ry: mul(ry)(s),

  toString() {
    return `cx="${this.cx}" cy="${this.cy}" rx="${this.rx}" ry="${this.ry}"`;
  }
});

const scaleCircleCoords = (cx: number, cy: number, r: number) => (s: number) => ({
  cx: scaleX(cx)(s),
  cy: scaleY(cy)(s),
  r: mul(r)(s),

  toString() {
    return `cx="${this.cx}" cy="${this.cy}" r="${this.r}"`;
  }
});

const scalePath = (p: string) => (s: number) =>
  SvgPath.from(p)
    .translate(-transformOriginX, -transformOriginY)
    .scale(s)
    .translate(transformOriginX, transformOriginY)
    .round(roundDigits);

export const chickenOutShadow = template<[scale: number]>/*svg*/ `
  <ellipse class="co-shadow" style="fill: #000; mix-blend-mode: overlay" ${scaleEllipseCoords(
    371,
    636,
    73,
    11
  )}/>
`;

export const chickenOutLeftLeg = (() => {
  const p = [
    "M289.11,532.28c-2,.82-4.27.09-5-1.61s.43-3.78,2.47-4.6l35.27-14.16c2-.81,4.27-.09,5,1.62s-.43,3.78-2.47,4.59Z",
    "M283.24,521l7.94,3.15a.84.84,0,0,1,.44.45l1.26,3.16a16.26,16.26,0,0,1,.77,7.64l-1.37,7.41c-.32,1.76-2.54,1.81-3.25.06l-7.79-19.43C280.39,521.29,281.29,520.19,283.24,521Z"
  ];

  return template<[scale: number]>/*svg*/ `
    <g class="co-left-leg">
      <path style="fill: #352d20" d="${scalePath(p[0])}"/>
      <path style="fill: #352d20" d="${scalePath(p[1])}"/>
    </g>
  `;
})();

export const chickenOutRightLeg = (() => {
  const p = [
    "M447.47,533.84c1.69,1.41,2.1,3.72.92,5.13s-3.53,1.41-5.21,0l-29.13-24.41c-1.68-1.42-2.1-3.73-.91-5.14s3.53-1.41,5.21,0Z",
    "M440.27,544.36l-1-8.49a.8.8,0,0,1,.2-.6l2.18-2.61a16.31,16.31,0,0,1,6.38-4.28l7.17-2.29c1.71-.54,2.8,1.39,1.59,2.84l-13.45,16C441.9,546.71,440.51,546.44,440.27,544.36Z"
  ];

  return template<[scale: number]>/*svg*/ `
    <g class="co-right-leg">
      <path style="fill: #352d20" d="${scalePath(p[0])}"/>
      <path style="fill: #352d20" d="${scalePath(p[1])}"/>
    </g>
  `;
})();

export const chickenOutBeak = (() => {
  const p =
    "M457.78,399.49l14.84,3.42a1.34,1.34,0,0,1,.62,2.28l-11.07,10.4A1.34,1.34,0,0,1,460,415l-3.77-13.82A1.34,1.34,0,0,1,457.78,399.49Z";

  return template<[scale: number]>/*svg*/ `
    <path style="fill: #f69222" d="${scalePath(p)}"/>
  `;
})();

export const chickenOutChicken = (() => {
  const p = [
    "M439.89,379c-13.52-8.26-25.81-9.63-37.27-7-11.4,2.05-28.31,8.23-30.57,7.28-2.45-1,2.18,1.39,7.56,3.06-29.52,19-54.75,53.65-84.54,39.83-19.12-8.87-2,57.56,26.39,84.11s83.14,20.67,115.86-14.37S470.34,397.6,439.89,379Z",
    "M460.06,408.88a56.06,56.06,0,0,1-14.61,38.89c-32.09,36.68-78.86,45.87-123.48,58.92,28.56,26,82.82,20,115.35-14.82C459.1,468.56,466.51,434.53,460.06,408.88Z",
    "M439.89,379c-13.52-8.26-25.81-9.63-37.27-7-11.4,2.05-28.31,8.23-30.57,7.28-2.45-1,2.18,1.39,7.56,3.06-29.52,19-54.75,53.65-84.54,39.83-19.12-8.87-2,57.56,26.39,84.11s83.14,20.67,115.86-14.37S470.34,397.6,439.89,379Z"
  ];

  return template<[scale: number], { style: string }>/*svg*/ `
    <path style="${style}" d="${scalePath(p[0])}"/>
    <path style="fill: #000; mix-blend-mode: soft-light" d="${scalePath(p[1])}"/>
    <path style="fill: #000; mix-blend-mode: soft-light" d="${scalePath(p[2])}"/>
  `;
})();

export const chickenOutEye = template<[scale: number]>/*svg*/ `
  <circle style="fill: #fff" ${scaleCircleCoords(434.63, 395.88, 8.32)}/>
  <circle style="fill: #000" ${scaleCircleCoords(434.64, 395.88, 5.63)}/>
`;

export const chickenOutShell = (() => {
  const p = [
    "M426.88,478.3c-4.32-14.77-13.07-27.43-18.93-42-11.59,9.87-27.89,14.38-41.82,20.47-9.38-13.84-14.24-17.3-23.24-29.78-14.77,4.32-20.12,4.84-33.81,10.28-3.64-14.39-9.18-27.87-14.88-41.62a120.2,120.2,0,0,0-12.33,24.53c-17.51,49.38,7.92,103.45,56.8,120.78s102.69-8.65,120.2-58a123.69,123.69,0,0,0,5.72-24.23C453.05,467,439.9,472.1,426.88,478.3Z",
    "M426.88,478.3c-.07-.22-.14-.43-.2-.64-24.85,26.9-64,38-100.37,25.11a93,93,0,0,1-49.67-41.44,93.84,93.84,0,0,0,61.87,79.59c48.88,17.33,102.7-8.65,120.21-58a124.21,124.21,0,0,0,5.7-24.07C452.92,467.09,439.83,472.13,426.88,478.3Z"
  ];

  return template<[scale: number], { style: string }>/*svg*/ `
    <path style="${style}" d="${scalePath(p[0])}"/>
    <path style="fill: #000; mix-blend-mode: soft-light" d="${scalePath(p[1])}"/>
  `;
})();
