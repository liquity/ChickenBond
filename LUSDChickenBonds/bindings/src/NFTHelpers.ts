import assert from "assert";
import fs from "fs-extra";
import path from "path";
import { BigNumberish } from "@ethersproject/bignumber";

const findAttributeValue = (metadata: any, attributeKey: string) => {
  for (const attribute of metadata.attributes) {
    if (attribute.trait_type === attributeKey) {
      return attribute.value;
    }
  }
  return null;
};

const checkAttribute = (eggMetadata: object, finalMetadata: object, attributeKey: string, optional: boolean = false) => {
  const finalAttribute = findAttributeValue(finalMetadata, attributeKey);
  if (optional && !finalAttribute) { return true; }

  const eggAttribute = findAttributeValue(eggMetadata, attributeKey);

  if (eggAttribute === finalAttribute) {
    return true;
  }

  console.log('trait: ', attributeKey);
  console.log('eggAttribute:   ', eggAttribute);
  console.log('finalAttribute: ', finalAttribute);
  return false;
};

export const checkMetadata = (eggMetadata: object, finalMetadata: object) => {
  // Border
  assert(checkAttribute(eggMetadata, finalMetadata, "Border"));
  // Card
  assert(checkAttribute(eggMetadata, finalMetadata, "Card"));
  // Shell
  assert(checkAttribute(eggMetadata, finalMetadata, "Shell", true));
};

export const writeNFT = async (bondID: BigNumberish, tokenURI: string, jsonDir: string, svgDir: string, fileSuffix: string) => {
  const expectedTokenURIScheme = "data:application/json;base64,";
  const expectedImageURIScheme = "data:image/svg+xml;base64,";

  assert(tokenURI.startsWith(expectedTokenURIScheme));

  const metadata = JSON.parse(
    Buffer.from(tokenURI.replace(expectedTokenURIScheme, ""), "base64").toString()
  );

  const imageURI = metadata.image;
  assert(typeof imageURI === "string");
  assert(imageURI.startsWith(expectedImageURIScheme));

  const svg = Buffer.from(imageURI.replace(expectedImageURIScheme, ""), "base64").toString();

  fs.writeFileSync(
    path.join(jsonDir, `${bondID}-${fileSuffix}.json`),
    JSON.stringify(metadata, null, 2)
  );

  fs.writeFileSync(path.join(svgDir, `${bondID}-${fileSuffix}.svg`), svg);

  return metadata;
};
