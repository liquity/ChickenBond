#!/bin/bash
set -e

# Change directory to this file so we can run this script from anywhere
cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'

# Script arguments - can also be set as env variables (arguments take precedence over env)
#  - 1) Ethereum RPC URL
#  - 2) Deployer private key
RPC_URL=${1:-${RPC_URL:-"http://localhost:8545/"}}
DEPLOYER_PRIVATE_KEY=${2:-${DEPLOYER_PRIVATE_KEY:-"0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7"}}

# Contract addresses (Mainnet)
MAINNET_LUSD_TOKEN_ADDRESS="0x5f98805A4E8be255a32880FDeC7F6728C6568bA0"
MAINNET_CURVE_POOL_ADDRESS="0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA"
MAINNET_CURVE_BASEPOOL_ADDRESS="0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
# MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS="0x378cb52b00F9D0921cb46dFc099CFf73b42419dC"
MAINNET_YEARN_CURVE_VAULT_ADDRESS="0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6"
MAINNET_YEARN_REGISTRY_ADDRESS="0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804"
MAINNET_YEARN_GOVERNANCE_ADDRESS="0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52"
MAINNET_CURVE_V2_FACTORY_ADDRESS="0xB9fC157394Af804a3578134A6585C0dc9cc990d4"
ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# Make sure RPC URL is up
cast client --rpc-url $RPC_URL > /dev/null || { 
  echo -e "\n${RED}RPC_URL $RPC_URL isn't up and running.\n"
  exit 1
}

# Deploy BondNFT contract
echo "Deploying BondNFT..."
BOND_NFT_ADDRESS=$(
  forge create BondNFT \
  --contracts ./src/BondNFT.sol \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --constructor-args "LUSDBondNFT" "LUSDBOND"  \
  | sed -nr 's/^Deployed to: (.*)$/\1/p'
)

# Verify BondNFT deployment
cast call $BOND_NFT_ADDRESS "owner()(address)" --rpc-url $RPC_URL > /dev/null || {
  echo -e "\n${RED}Failed to deploy BondNFT contract."
  exit 1
}

echo -e "Deployed to: $BOND_NFT_ADDRESS\n"

# Deploy BLUSDToken contract
echo "Deploying BLUSDToken..."
BLUSD_TOKEN_ADDRESS=$(
  forge create BLUSDToken \
  --contracts ./src/BLUSDToken.sol \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --constructor-args "Boosted LUSD" "bLUSD" \
  | sed -nr 's/^Deployed to: (.*)$/\1/p'
)

# Verify BLUSDToken deployment
cast call $BLUSD_TOKEN_ADDRESS "owner()(address)" --rpc-url $RPC_URL > /dev/null || {
  echo -e "\n${RED}Failed to deploy BLUSDToken contract."
  exit 1
}

echo -e "Deployed to: $BLUSD_TOKEN_ADDRESS\n"

# Create bLUSD AMM pool
BLUSD_AMM_ADDRESS=$(
  cast call $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_plain_pool(string,string,address[4],uint256,uint256,uint256,uint256)(address)" \
  bLUSD_LUSD \
  bLUSDLUSDC \
  [$BLUSD_TOKEN_ADDRESS,$MAINNET_LUSD_TOKEN_ADDRESS,$ZERO_ADDRESS,$ZERO_ADDRESS] \
  1000 \
  4000000 \
  1 \
  1 \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY
)

cast send $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_plain_pool(string,string,address[4],uint256,uint256,uint256,uint256)(address)" \
bLUSD_LUSD \
bLUSDLUSDC \
[$BLUSD_TOKEN_ADDRESS,$MAINNET_LUSD_TOKEN_ADDRESS,$ZERO_ADDRESS,$ZERO_ADDRESS] \
1000 \
4000000 \
1 \
1 \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || { 
  echo -e "\n${RED}Failed to create AMM pool"
  exit 1
}

echo -e "Created Curve AMM pool for LUSD/bLUSD\n"

# Create bLUSD AMM staking reward contract
BLUSD_AMM_STAKING_ADDRESS=$(
  cast call $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_gauge(address)(address)" \
  $BLUSD_AMM_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY
)

cast send $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_gauge(address)(address)" \
$BLUSD_AMM_ADDRESS \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || { 
  echo -e "\n${RED}Failed to create AMM pool staking contract"
  exit 1
}

echo -e "Created LUSD/bLUSD staking contract (gauge)\n"

# Temporary until we have a mainnet LUSD BAMM address
echo -e "Deploying LUSD BAMM...\n"

MAINNET_CHAINLINK_ETH_USD_ADDRESS="0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"
MAINNET_CHAINLINK_LUSD_USD_ADDRESS="0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0"
MAINNET_LIQUITY_SP_ADDRESS="0x66017D22b0f8556afDd19FC67041899Eb65a21bb"
MAINNET_LQTY_TOKEN_ADDRESS="0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D"
MAINNET_BPROTOCOL_FEE_POOL_ADDRESS="0x7095F0B91A1010c11820B4E263927835A4CF52c9"

MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS=$(
forge create BAMM \
--contracts ./lib/b-protocol/packages/contracts/contracts/B.Protocol/BAMM.sol \
--private-key $DEPLOYER_PRIVATE_KEY \
--rpc-url $RPC_URL \
--constructor-args \
$MAINNET_CHAINLINK_ETH_USD_ADDRESS \
$MAINNET_CHAINLINK_LUSD_USD_ADDRESS \
$MAINNET_LIQUITY_SP_ADDRESS \
$MAINNET_LUSD_TOKEN_ADDRESS \
$MAINNET_LQTY_TOKEN_ADDRESS \
400 \
$MAINNET_BPROTOCOL_FEE_POOL_ADDRESS \
$ZERO_ADDRESS \
0 \
| sed -nr 's/^Deployed to: (.*)$/\1/p'
)

# Verify BAMM deployment
cast call $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS "owner()(address)" --rpc-url $RPC_URL || {
  echo -e "\n${RED}Failed to deploy BAMM contract."
  exit 1
}

echo -e "Deployed to: $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS\n"

# Deploy ChickenBondManager contract
echo "Deploying ChickenBondManager..."

# ChickenBonds constructor arguments
INITIAL_ACCRUAL_PARAMETER=2592000000000000000000000         # 30 days * 1e18
MINIMUM_ACCRUAL_PARAMETER=2592000000000000000000            # 30 days * e18 / 1000
ACCRUAL_ADJUSTMENT_RATE=10000000000000000                   # 1e16 = 1%
TARGET_AVERAGE_AGE_SECONDS=2592000                          # 30 days
ACCRUAL_ADJUSTMENT_PERIOD_SECONDS=86400                     # 1 day
CHICKEN_IN_AMM_FEE=10000000000000000                        # 1e16 = 1%
CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD=1000400000000000000   # 10004e14 = 1.0004

EXTERNAL_ADDRESSES="(\
$BOND_NFT_ADDRESS,\
$MAINNET_LUSD_TOKEN_ADDRESS,\
$MAINNET_CURVE_POOL_ADDRESS,\
$MAINNET_CURVE_BASEPOOL_ADDRESS,\
$MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS,\
$MAINNET_YEARN_CURVE_VAULT_ADDRESS,\
$MAINNET_YEARN_REGISTRY_ADDRESS,\
$MAINNET_YEARN_GOVERNANCE_ADDRESS,\
$BLUSD_TOKEN_ADDRESS,\
$BLUSD_AMM_STAKING_ADDRESS)"

CHICKEN_BOND_MANAGER_ADDRESS=$(
forge create ChickenBondManager \
--contracts ./src/ChickenBondManager.sol \
--private-key $DEPLOYER_PRIVATE_KEY \
--rpc-url $RPC_URL \
--constructor-args \
$EXTERNAL_ADDRESSES \
$TARGET_AVERAGE_AGE_SECONDS \
$INITIAL_ACCRUAL_PARAMETER \
$MINIMUM_ACCRUAL_PARAMETER \
$ACCRUAL_ADJUSTMENT_RATE \
$ACCRUAL_ADJUSTMENT_PERIOD_SECONDS \
$CHICKEN_IN_AMM_FEE \
$CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD \
$CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD \
| sed -nr 's/^Deployed to: (.*)$/\1/p'
)

# Verify ChickenBondManager deployment
cast call $CHICKEN_BOND_MANAGER_ADDRESS "getPendingLUSD()(uint256)" --rpc-url $RPC_URL || {
  echo -e "\n${RED}Failed to deploy ChickenBondManager contract."
  exit 1
}

echo -e "Deployed to: $CHICKEN_BOND_MANAGER_ADDRESS\n"

# Connect ChickenBond contracts
echo "Connecting BondNFT to ChickenBondManager..."
cast send $BOND_NFT_ADDRESS "setAddresses(address)" $CHICKEN_BOND_MANAGER_ADDRESS \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || exit 1
echo -e "Done.\n"

echo "Connecting BLUSDToken to ChickenBondManager..."
cast send $BLUSD_TOKEN_ADDRESS "setAddresses(address)" $CHICKEN_BOND_MANAGER_ADDRESS \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || exit 1
echo -e "Done.\n"

echo "Connecting ChickenBondManager to BAMM..."
cast send $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS "setChicken(address)" $CHICKEN_BOND_MANAGER_ADDRESS \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || exit 1
echo -e "Done.\n"

DEPLOYMENT_ADDRESSES=$(printf '{
  "BOND_NFT_ADDRESS": "%s",
  "BLUSD_TOKEN_ADDRESS": "%s",
  "BLUSD_AMM_STAKING_ADDRESS": "%s",
  "BLUSD_AMM_ADDRESS": "%s",
  "CHICKEN_BOND_MANAGER_ADDRESS": "%s"
}\n' $BOND_NFT_ADDRESS $BLUSD_TOKEN_ADDRESS $BLUSD_AMM_STAKING_ADDRESS $BLUSD_AMM_ADDRESS $CHICKEN_BOND_MANAGER_ADDRESS)

echo -e "${GREEN}Finished.\n"
echo -e "${DEPLOYMENT_ADDRESSES}\n"

rm -f ../addresses/addresses.json
echo $DEPLOYMENT_ADDRESSES | python -m json.tool > ../addresses/addresses.json
