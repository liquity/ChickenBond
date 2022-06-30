#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Compiling LUSD TypeScript files...\n"

npx tsc

echo -e "Finished compiling LUSD.\n"
