#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Watching TypeScript files...\n"

# When ChickenBonds typescript changes, recompile
nodemon --delay 1 -e ts,json \
--watch ../types/ \
--watch ../addresses/ \
--on-change-only \
--exec "echo 'Recompiling TypeScript files...\n' && yarn compile"

