import {
  isCardGradient,
  isMetallicColor,
  isRainbowColor,
  metallicColors,
  solidBorderColors,
  solidCardColors
} from "../../traits";
import { CommonArtworkParams } from "./types";

export const borderFill = ({ tokenID, borderColor }: CommonArtworkParams) =>
  isRainbowColor(borderColor)
    ? `url(#cb-egg-${tokenID}-card-rainbow-gradient)`
    : isMetallicColor(borderColor)
    ? metallicColors[borderColor].solid
    : solidBorderColors[borderColor];

export const lightModeBorder = (params: CommonArtworkParams) => /*svg*/ `
  <!-- border -->
  <rect style="fill: ${borderFill(params)}" width="100%" height="100%" rx="37.5" />
`;

export const darkModeBorder = (params: CommonArtworkParams) =>
  params.borderColor === "black"
    ? "" // We use the black radial gradient as border (covering the entire card)
    : lightModeBorder(params);

export const lightModeCard = ({ tokenID, borderColor, cardColor }: CommonArtworkParams) => /*svg*/ `
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
`;

export const darkModeCard = (params: CommonArtworkParams) => /*svg*/ `
  ${lightModeCard(params)}

  <!-- black radial gradient -->
  ${
    params.borderColor === "black"
      ? /*svg*/ `
          <rect width="100%" height="100%" rx="37.5" style="mix-blend-mode: hard-light; fill: url(#cb-egg-${params.tokenID}-card-radial-gradient)"/>`
      : /*svg*/ `
          <rect x="30" y="30" width="690" height="990" rx="37.5" style="mix-blend-mode: hard-light; fill: url(#cb-egg-${params.tokenID}-card-radial-gradient)"/>`
  }
`;

export const text = (subtitle: string, { tokenID }: CommonArtworkParams) => /*svg*/ `
  <!-- text -->
  <text fill="#fff" font-family="'Arial Black', Arial" font-size="72px" font-weight="800" text-anchor="middle" x="50%" y="14%">LUSD</text>
  <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="19%">ID: ${tokenID}</text>
  <text fill="#fff" font-family="'Arial Black', Arial" font-size="40px" font-weight="800" text-anchor="middle" x="50%" y="72%">${subtitle}</text>
  <text fill="#fff" font-family="'Arial Black', Arial" font-size="64px" font-weight="800" text-anchor="middle" x="50%" y="81%">1337</text>
  <text fill="#fff" font-family="'Arial Black', Arial" font-size="30px" font-weight="800" text-anchor="middle" x="50%" y="91%" opacity="0.6">JANUARY 1, 1970</text>
`;
