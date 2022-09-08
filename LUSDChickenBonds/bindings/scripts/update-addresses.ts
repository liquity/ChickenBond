import fs from "fs-extra";
import path from "path";

import deployment from "../deployments/goerli.json";

const outDir = path.join("..", "addresses");
const outFiles = ["addresses.json", "goerli.json"].map(outFile => path.join(outDir, outFile));

const addresses = JSON.stringify(
  {
    BLUSD_AMM_ADDRESS: deployment.addresses.bLUSDCurvePool,
    BLUSD_AMM_STAKING_ADDRESS: deployment.addresses.curveLiquidityGauge,
    BLUSD_TOKEN_ADDRESS: deployment.addresses.bLUSDToken,
    BOND_NFT_ADDRESS: deployment.addresses.bondNFT,
    CHICKEN_BOND_MANAGER_ADDRESS: deployment.addresses.chickenBondManager,
    LUSD_OVERRIDE_ADDRESS: deployment.addresses.lusdToken
  },
  null,
  4
);

for (const outFile of outFiles) {
  fs.writeFileSync(outFile, addresses);
}
