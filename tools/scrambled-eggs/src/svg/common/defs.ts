import {
  cardGradients,
  isCardGradient,
  isMetallicColor,
  isRainbowColor,
  metallicColors
} from "../../traits";

import { CommonArtworkParams } from "./types";

export const lightModeDefs = ({ tokenID, cardColor, borderColor }: CommonArtworkParams) => /*svg*/ `
  ${
    isCardGradient(cardColor) || isMetallicColor(cardColor)
      ? /*svg*/ `
          <!-- diagonal card gradient -->
          <linearGradient id="cb-egg-${tokenID}-card-diagonal-gradient" y1="100%" gradientUnits="userSpaceOnUse">
            ${
              isCardGradient(cardColor)
                ? /*svg*/ `
                    <stop offset="0" stop-color="${cardGradients[cardColor][0]}"/>
                    <stop offset="1" stop-color="${cardGradients[cardColor][1]}"/>
                  `
                : /*svg*/ `
                    <stop offset="0" stop-color="${metallicColors[cardColor].gradient[0]}"/>
                    <stop offset="1" stop-color="${metallicColors[cardColor].gradient[1]}"/>
                  `
            }
          </linearGradient>
        `
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
`;

export const darkModeDefs = (params: CommonArtworkParams) => /*svg*/ `
  ${lightModeDefs(params)}

  <!-- black radial gradient (spotlight) -->
  <radialGradient
    id="cb-egg-${params.tokenID}-card-radial-gradient"
    cx="50%"
    cy="45%"
    r="38%"
    gradientUnits="userSpaceOnUse"
  >
    <stop offset="0" stop-opacity="0"/>
    <stop offset="0.25" stop-opacity="0"/>
    <stop offset="1" stop-color="#000" stop-opacity="1"/>
  </radialGradient>
`;
