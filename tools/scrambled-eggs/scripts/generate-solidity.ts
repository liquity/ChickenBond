import fs from "fs";
import path from "path";

import { chickenOutSolidity } from "../src/svg/chickenOut";
import { chickenInSolidity } from "../src/svg/chickenIn";

const outDir = path.join("..", "..", "LUSDChickenBonds", "src", "NFTArtwork");

fs.writeFileSync(path.join(outDir, "ChickenOutGenerated.sol"), chickenOutSolidity());
fs.writeFileSync(path.join(outDir, "ChickenInGenerated.sol"), chickenInSolidity());
