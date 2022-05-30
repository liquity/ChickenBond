#!/usr/bin/env bash

# NOTE: you should run this script from the parent directory, i.e. LUSDChickenBonds.

outputDir=etc
outputFile=${outputDir}/slither-report.md

commit=$(git rev-parse HEAD) || exit

slitherCmd=(
  slither
    --filter-paths 'lib|(src/(test|ExternalContracts|utils/console.sol))'
    --checklist
    --markdown-root "https://github.com/liquity/ChickenBond/blob/${commit}/LUSDChickenBonds/"
    .
)

mkdir -p "${outputDir}"
"${slitherCmd[@]}" > "${outputFile}"
