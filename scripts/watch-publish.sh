#!/bin/bash
set -e

# Change directory to this location so we can run this script from anywhere
cd "$(dirname "$0")"

echo -e "Watching LUSD / LQTY compilations...\n"

nodemon --delay 5 -e js,json --watch ../lusd/dist/ --on-change-only --exec 'yarn publish:local'

