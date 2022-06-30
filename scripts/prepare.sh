#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

# Merge specific compilations in a single dist folder
echo -e "Preparing compilations...\n"

rm -rf ../dist/lusd
mkdir -p ../dist/lusd
cp -r ../lusd/dist/. ../dist/lusd

# rm -rf ../dist/lqty
# mkdir -p ../dist/lqty
# cp -r ../lqty/dist/. ../dist/lqty

echo -e "Finished preparing compilations to ./dist\n"
