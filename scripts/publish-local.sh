#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Publishing dist to local store...\n"

# Generate dist output to publish
yarn prepare-publish

# Publish with ./dist as the root, so consumers don't have to import with "/dist" in the path
cp ../package.json ../dist
yalc push --changed ../dist

echo -e "Finished publishing dist to local store.\n"
