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
MAINNET_CURVE_V2_FACTORY_ADDRESS="0xF18056Bbd320E96A48e3Fbf8bC061322531aac99"
MAINNET_CURVE_V2_FACTORY_ADMIN_ADDRESS="0xbabe61887f1de2713c6f97e567623453d3c79f67"
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
  --constructor-args LUSDBondNFT LUSDBOND $ZERO_ADDRESS 86400 \
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
echo "Creating bLUSD Curve AMM pool (bLUSD/LUSD)..."

BLUSD_AMM_ADDRESS=$(
  cast call $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_pool(string,string,address[2],uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)(address)" \
  bLUSD_LUSD \
  bLUSDLUSDC \
  "[$BLUSD_TOKEN_ADDRESS,$MAINNET_LUSD_TOKEN_ADDRESS]" \
  4000 \
  145000000000000 \
  50000000 \
  100000000 \
  2000000000000 \
  2300000000000000 \
  146000000000000 \
  5000000000 \
  86400 \
  1200000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY
)

cast send $MAINNET_CURVE_V2_FACTORY_ADDRESS "deploy_pool(string,string,address[2],uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)(address)" \
bLUSD_LUSD \
bLUSDLUSDC \
"[$BLUSD_TOKEN_ADDRESS,$MAINNET_LUSD_TOKEN_ADDRESS]" \
4000 \
145000000000000 \
50000000 \
100000000 \
2000000000000 \
2300000000000000 \
146000000000000 \
5000000000 \
86400 \
1200000000000000000 \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY > /dev/null || { 
  echo -e "\n${RED}Failed to create bLUSD/LUSD Curve AMM pool"
  exit 1
}
echo -e "Deployed to: $BLUSD_AMM_ADDRESS\n"

echo "Creating bLUSD/LUSD staking reward contract (Curve gauge)"
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

echo -e "Deployed to: $BLUSD_AMM_STAKING_ADDRESS\n"

# Temporary until we have a mainnet LUSD BAMM address
echo "Deploying LUSD BAMM..."

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
INITIAL_ACCRUAL_PARAMETER=216000000000000000000000          # 2.5 days * 1e18
MINIMUM_ACCRUAL_PARAMETER=216000000000000000000             # 2.5 days * 1e18 / 1000
ACCRUAL_ADJUSTMENT_RATE=10000000000000000                   # 1e16 = 1%
TARGET_AVERAGE_AGE_SECONDS=2592000                          # 30 days
ACCRUAL_ADJUSTMENT_PERIOD_SECONDS=86400                     # 1 day
CHICKEN_IN_AMM_FEE=10000000000000000                        # 1e16 = 1%
CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD=1000400000000000000   # 10004e14 = 1.0004
# BOOTSTRAP_PERIOD_CHICKEN_IN=604800                          # 7 days
# BOOTSTRAP_PERIOD_REDEEM=604800                              # 7 days
BOOTSTRAP_PERIOD_CHICKEN_IN=1                               # 7 days
BOOTSTRAP_PERIOD_REDEEM=1                                   # 7 days
BOOTSTRAP_PERIOD_SHIFT=7776000                              # 90 days
SHIFTER_DELAY=3600                                          # 1 hour
SHIFTER_WINDOW=600                                          # 10 minutes
MIN_BLUSD_SUPPLY=1000000000000000000                        # 1 bLUSD
MIN_BOND_AMOUNT=100000000000000000000                       # 100 LUSD
NFT_RANDOMNESS_DIVISOR=1000000000000000000000               # 1000
REDEMPTION_FEE_BETA=2
REDEMPTION_FEE_MINUTE_DECAY_FACTOR=999037758833783000       # 12 hour half life

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

PARAMS="(\
$TARGET_AVERAGE_AGE_SECONDS,\
$INITIAL_ACCRUAL_PARAMETER,\
$MINIMUM_ACCRUAL_PARAMETER,\
$ACCRUAL_ADJUSTMENT_RATE,\
$ACCRUAL_ADJUSTMENT_PERIOD_SECONDS,\
$CHICKEN_IN_AMM_FEE,\
$CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD,\
$CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD,\
$BOOTSTRAP_PERIOD_CHICKEN_IN,\
$BOOTSTRAP_PERIOD_REDEEM,\
$BOOTSTRAP_PERIOD_SHIFT,\
$SHIFTER_DELAY,\
$SHIFTER_WINDOW,\
$MIN_BLUSD_SUPPLY,\
$MIN_BOND_AMOUNT,\
$NFT_RANDOMNESS_DIVISOR,\
$REDEMPTION_FEE_BETA,\
$REDEMPTION_FEE_MINUTE_DECAY_FACTOR)"

CHICKEN_BOND_MANAGER_ADDRESS=$(
forge create ChickenBondManager \
--contracts ./src/ChickenBondManager.sol \
--private-key $DEPLOYER_PRIVATE_KEY \
--rpc-url $RPC_URL \
--constructor-args \
$EXTERNAL_ADDRESSES \
$PARAMS \
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

echo "Adding LUSD reward token for bLUSD/LUSD LPs, and set ChickenBondManager as distributor in Curve gauge..."
cast rpc "hardhat_impersonateAccount" $MAINNET_CURVE_V2_FACTORY_ADMIN_ADDRESS
cast send $BLUSD_AMM_STAKING_ADDRESS "add_reward(address,address)" \
$MAINNET_LUSD_TOKEN_ADDRESS $CHICKEN_BOND_MANAGER_ADDRESS \
--rpc-url $RPC_URL \
--from $MAINNET_CURVE_V2_FACTORY_ADMIN_ADDRESS > /dev/null || exit 1
echo -e "Done.\n"


DEPLOYMENT_ADDRESSES=$(printf '{
  "BOND_NFT_ADDRESS": "%s",
  "BLUSD_TOKEN_ADDRESS": "%s",
  "BLUSD_AMM_ADDRESS": "%s",
  "BLUSD_AMM_STAKING_ADDRESS": "%s",
  "CHICKEN_BOND_MANAGER_ADDRESS": "%s",
  "LUSD_OVERRIDE_ADDRESS": null
}\n' $BOND_NFT_ADDRESS $BLUSD_TOKEN_ADDRESS $BLUSD_AMM_ADDRESS $BLUSD_AMM_STAKING_ADDRESS $CHICKEN_BOND_MANAGER_ADDRESS)

echo -e "${GREEN}Finished.\n"
echo -e "${DEPLOYMENT_ADDRESSES}\n"

rm -f ../addresses/addresses.json

PYTHON_CMD="python"
if ! command -v $PYTHON_CMD &> /dev/null
then
  PYTHON_CMD="python3"
  if ! command -v $PYTHON_CMD &> /dev/null
  then
    echo "Couldn't find python or python3, do you have it installed under a different alias?"
    exit
  fi
fi

echo $DEPLOYMENT_ADDRESSES | $PYTHON_CMD -m json.tool > ../addresses/addresses.json
