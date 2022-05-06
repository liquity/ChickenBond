#!/usr/bin/env bash

outputFile=deployment.json

# ChickenBondManager params
targetAverageAgeSeconds=2592000
initialAccrualParameter=2592000000000000000000000
minimumAccrualParameter=2592000000000000000000
accrualAdjustmentRate=10000000000000000
accrualAdjustmentPeriodSeconds=86400

# config
rpcUrl=http://127.0.0.1:8545/
privateKey=0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7

# constants
zeroAddress=0x0000000000000000000000000000000000000000

forgeCreateCmd=(
  forge create
    --rpc-url "${rpcUrl}"
    --private-key "${privateKey}"
)

castSendCmd=(
  cast send
    --rpc-url "${rpcUrl}"
    --private-key "${privateKey}"
)

deploy() {
  local contract=${1}
  local constructorArgs=()

  shift

  if [ ${#} -gt 0 ]; then
    constructorArgs=(
      --constructor-args "${@}"
    )
  fi

  local address=$(
    "${forgeCreateCmd[@]}" "${contract}" "${constructorArgs[@]}" |
      sed -n -r 's/^Deployed to: (.*)$/\1/p'
  )

  echo "${contract}: ${address}" >&2
  echo "${address}"
}

send() {
  "${castSendCmd[@]}" "${@}"
}

formatJson() {
  echo '{'

  while [ $# -gt 1 ]; do
    echo '  "'"${1}"'": "'${!1}'",'
    shift
  done

  if [ $# -eq 1 ]; then
    echo '  "'"${1}"'": "'${!1}'"'
  fi

  echo '}'
}

lusdToken=$(deploy LUSDTokenTester ${zeroAddress} ${zeroAddress} ${zeroAddress})
curvePool=$(deploy MockCurvePool 'LUSD-3CRV Pool' 'LUSD3CRV-f')
yearnLUSDVault=$(deploy MockYearnVault 'LUSD yVault' 'yvLUSD')
yearnCurveVault=$(deploy MockYearnVault 'Curve LUSD Pool yVault' 'yvCurve-LUSD')

deployYearnRegistryCmd=(
  deploy MockYearnRegistry
    ${yearnLUSDVault}
    ${yearnCurveVault}
    ${lusdToken}
    ${curvePool}
)

yearnRegistry=$("${deployYearnRegistryCmd[@]}")
sLUSDToken=$(deploy SLUSDToken 'sLUSDToken' 'SLUSD')
bondNFT=$(deploy BondNFT 'LUSDBondNFT' 'LUSDBOND')

deployChickenBondManagerCmd=(
  deploy ChickenBondManager
    ${bondNFT}
    ${lusdToken}
    ${curvePool}
    ${yearnLUSDVault}
    ${yearnCurveVault}
    ${sLUSDToken}
    ${yearnRegistry}
    ${targetAverageAgeSeconds}
    ${initialAccrualParameter}
    ${minimumAccrualParameter}
    ${accrualAdjustmentRate}
    ${accrualAdjustmentPeriodSeconds}
)

chickenBondManager=$("${deployChickenBondManagerCmd[@]}")

send ${bondNFT} 'setAddresses(address)' ${chickenBondManager}
send ${sLUSDToken} 'setAddresses(address)' ${chickenBondManager}

fields=(
  lusdToken
  curvePool
  yearnLUSDVault
  yearnCurveVault
  yearnRegistry
  sLUSDToken
  bondNFT
  chickenBondManager
)

echo
formatJson "${fields[@]}" | tee "${outputFile}"
