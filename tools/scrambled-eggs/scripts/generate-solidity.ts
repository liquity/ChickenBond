import fs from "fs";
import path from "path";

import { chickenOutSolidity } from "../src/svg/chickenOut";

const outDir = path.join("..", "..", "LUSDChickenBonds", "src", "NFTArtwork");

fs.writeFileSync(path.join(outDir, "ChickenOutGenerated.sol"), chickenOutSolidity());
