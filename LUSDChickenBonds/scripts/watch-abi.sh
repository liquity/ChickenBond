#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Watching Solidity ABIs...\n"

# When ChickenBonds ABIs change, regenerate the types
nodemon --delay 1 -e json \
--watch ../out/BondNFT.sol/ \
--watch ../out/BLUSDToken.sol/ \
--watch ../out/ChickenBondManager.sol/ \
--watch ../out/BLUSDLPZap.sol/ \
--watch ../external-abis/ \
--on-change-only \
--exec "echo 'Regenerating ABI typescript files...\n' && yarn generate-types"

