#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Generating TypeScript types...\n"

# Generate ChickenBonds contract TS types for TypeScript consumers (e.g. frontends)
npx typechain --target ethers-v5 --out-dir ../types \
'../out/BondNFT.sol/BondNFT.json' \
'../out/BLUSDToken.sol/BLUSDToken.json' \
'../out/ChickenBondManager.sol/ChickenBondManager.json' \
'../out/LUSDSilo.sol/LUSDSilo.json' \

echo -e "\nFinished generating TypeScript types.\n"
