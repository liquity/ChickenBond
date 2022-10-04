#!/bin/bash
set -e

# Change directory to this file so we can run this script from anywhere
cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET_COLOR='\033[0m'

ZERO_ADDRESS=0x0000000000000000000000000000000000000000

ENV_FILE="config/.env"
[[ -f $ENV_FILE ]] && source $ENV_FILE

# Script arguments - can also be set as env variables (arguments take precedence over env)
#  - 1) Ethereum RPC URL
#  - 2) Deployer private key
ETH_RPC_URL=${ETH_RPC_URL:-"http://localhost:8545/"}
DEPLOYER_PRIVATE_KEY=${DEPLOYER_PRIVATE_KEY:-"4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7"}
PRIORITY_GAS_PRICE=${PRIORITY_GAS_PRICE:-""}
ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-""}
CONFIG_FILE="config/mainnet-dry-run.sh"
OUTPUT_FILE="../addresses/mainnet-dry-run.json"

usage() {
    echo "Usage: $0 [ -r ETH_RPC_URL ] [ -k DEPLOYER_PRIVATE_KEY ] [ -e ETHERSCAN_API_KEY ] [ -g PRIORITY_GAS_PRICE ] [ -c CONFIG_FILE ] [ -o OUTPUT_FILE ]" 1>&2
}
exit_abnormal() {
    usage
    exit 1
}
while getopts ":r:k:e:g:c:o:" options; do
    case "${options}" in
        r)
            ETH_RPC_URL=${OPTARG}
            ;;
        k)
            DEPLOYER_PRIVATE_KEY=${OPTARG}
            ;;
        e)
            ETHERSCAN_API_KEY=${OPTARG}
            ;;
        g)
            PRIORITY_GAS_PRICE=${OPTARG}
            ;;
        c)
            CONFIG_FILE=${OPTARG}
            ;;
        o)
            OUTPUT_FILE=${OPTARG}
            ;;
        :)
            echo "Error: -${OPTARG} requires an argument."
            exit_abnormal
            ;;
        *)
            exit_abnormal
            ;;
    esac
done

DEPLOYER_ADDRESS=$(cast wallet address --private-key $DEPLOYER_PRIVATE_KEY | cut -d" " -f2)
ETHERSCAN_TX_BASE_URL="https://etherscan.io/tx/"

echo ETH_RPC_URL: $ETH_RPC_URL
#echo DEPLOYER_PRIVATE_KEY: $DEPLOYER_PRIVATE_KEY
echo DEPLOYER_ADDRESS: $DEPLOYER_ADDRESS
echo ETHERSCAN_API_KEY: $ETHERSCAN_API_KEY
echo PRIORITY_GAS_PRICE: $PRIORITY_GAS_PRICE
echo CONFIG_FILE: $CONFIG_FILE
echo OUTPUT_FILE: $OUTPUT_FILE
echo ""

read -p "Do you want to proceed? (y/n) " proceed
[[ $proceed == "y" ]] || exit 1

# Load addresses and constructor arguments
source $CONFIG_FILE

# Make sure RPC URL is up
cast client --rpc-url $ETH_RPC_URL > /dev/null || {
  echo -e "\n${RED}ETH_RPC_URL $ETH_RPC_URL isn't up and running.\n"
  exit 1
}

DEPLOYMENT_ADDRESSES=''
DEPLOYMENT_TXS=''

# --- Helper functions ---

# Arguments:
# 1: contract file name
# 2: constructor params
# 3: Function to call for checking
# 4: json key for output addresses
# 5: contracts subpath
deploy_contract() {
    echo "Deploying $1..."

    RESULT=$(
        forge create "./src/$5$1.sol:$1" \
              --private-key $DEPLOYER_PRIVATE_KEY \
              --rpc-url $ETH_RPC_URL \
              ${PRIORITY_GAS_PRICE:+--priority-gas-price $PRIORITY_GAS_PRICE} \
              ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY --verify} \
              ${2:+--constructor-args $2})

    DEPLOYED_ADDRESS=$(echo $RESULT | sed -nr 's/.* Deployed to: (0x\w+) .*$/\1/p')
    TX_HASH=$(echo $RESULT | sed -nr 's/.* Transaction hash: (0x\w+).*$/\1/p')

    [[ -z $DEPLOYED_ADDRESS ]] && { echo -e "\n${RED}Failed to deploy $1 contract.";  exit 1; }

    RECEIPT=$(cast receipt $TX_HASH)
    GAS_USED=$(echo $RECEIPT | sed -nr 's/.* gasUsed ([0-9]+) .*$/\1/p')

    # Check deployment
    if [[ ! -z $3 ]]; then
        cast call $DEPLOYED_ADDRESS $3 --rpc-url $ETH_RPC_URL > /dev/null || {
            echo -e "\n${RED}Failed to deploy $1 contract."
            exit 1
        }
    fi

    DEPLOYMENT_ADDRESSES="$DEPLOYMENT_ADDRESSES \"$4\": \"$DEPLOYED_ADDRESS\","
    DEPLOYMENT_TXS="$DEPLOYMENT_TXS \n[${4%_ADDRESS}](${ETHERSCAN_TX_BASE_URL}${TX_HASH})\n"

    echo -e "Deployed to: $DEPLOYED_ADDRESS"
    echo -e "Tx hash: $TX_HASH"
    echo -e "Gas used: $GAS_USED"
    echo ""
}

# Arguments:
# 1: contract factory address
# 2: function signature
# 3: function arguments
# 4: json key for output addresses
# 5: contract description (for console logs)
deploy_from_factory() {
    echo "Creating $5..."
    DEPLOYED_ADDRESS=$(
        cast call $1 $2 $3 \
             --rpc-url $ETH_RPC_URL \
             --private-key $DEPLOYER_PRIVATE_KEY)

    [[ -z $DEPLOYED_ADDRESS ]] && { echo -e "\n${RED}Failed to deploy $5.";  exit 1; }

    RESULT=$(cast send $1 $2 $3 \
         --rpc-url $ETH_RPC_URL \
         --private-key $DEPLOYER_PRIVATE_KEY \
         ${PRIORITY_GAS_PRICE:+--priority-gas-price $PRIORITY_GAS_PRICE})

    GAS_USED=$(echo $RESULT | sed -nr 's/.* gasUsed ([0-9]+) .*$/\1/p')
    STATUS=$(echo $RESULT | sed -nr 's/.* status ([0-9]+) .*$/\1/p')
    TX_HASH=$(echo $RESULT | sed -nr 's/.* transactionHash (0x\w+) .*$/\1/p')
    [[ $STATUS == 1 ]] || { echo -e "\n${RED}Failed to deploy $5. Status: $STATUS";  exit 1; }
    [[ -z $TX_HASH ]] && { echo -e "\n${RED}Failed to deploy $5.";  exit 1; }

    DEPLOYMENT_ADDRESSES="$DEPLOYMENT_ADDRESSES \"$4\": \"$DEPLOYED_ADDRESS\","
    DEPLOYMENT_TXS="$DEPLOYMENT_TXS \n[${4%_ADDRESS}](${ETHERSCAN_TX_BASE_URL}${TX_HASH})\n"

    echo -e "Deployed to: $DEPLOYED_ADDRESS"
    echo -e "Tx hash: $TX_HASH"
    echo -e "Gas used: $GAS_USED"
    echo ""
}

# 1: target contract
# 2: function signature
# 3: function arguments
cast_send_wrapper() {
    RESULT=$(cast send $1 $2 $3 \
         --rpc-url $ETH_RPC_URL \
         --private-key $DEPLOYER_PRIVATE_KEY \
         ${PRIORITY_GAS_PRICE:+--priority-gas-price $PRIORITY_GAS_PRICE})

    GAS_USED=$(echo $RESULT | sed -nr 's/.* gasUsed ([0-9]+) .*$/\1/p')
    STATUS=$(echo $RESULT | sed -nr 's/.* status ([0-9]+) .*$/\1/p')
    TX_HASH=$(echo $RESULT | sed -nr 's/.* transactionHash (0x\w+) .*$/\1/p')
    [[ $STATUS == 1 ]] || { echo -e "\n${RED}Failed to deploy $5. Status: $STATUS";  exit 1; }
    [[ -z $TX_HASH ]] && { echo -e "\n${RED}Failed to deploy $5.";  exit 1; }

    echo -e "Tx hash: $TX_HASH"
    echo -e "Gas used: $GAS_USED"
    echo ""
}

# 1: target contract
# 2: function signature
# 3: function arguments
cast_call_wrapper() {
    set +e
    CALL_RESULT=$(cast call $1 $2 $3 \
         --rpc-url $ETH_RPC_URL \
         --private-key $DEPLOYER_PRIVATE_KEY)
    CALL_STATUS=$?
    set -e
}

# --- Deployments ---

# Make sure B.AMM address is set
if [[ -z $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS ]]; then
    read -p "Missing B.AMM. Do you want to deploy it? (y/n) " proceed
    [[ $proceed == "y" ]] || {
        echo -e "\n${RED}Missing B.AMM address!\n"
        exit 1
    }
    # Deploy B.AMM
    constructor_args="$MAINNET_CHAINLINK_ETH_USD_ADDRESS \
          $MAINNET_CHAINLINK_LUSD_USD_ADDRESS \
          $MAINNET_LIQUITY_SP_ADDRESS \
          $MAINNET_LUSD_TOKEN_ADDRESS \
          $MAINNET_LQTY_TOKEN_ADDRESS \
          400 \
          $MAINNET_BPROTOCOL_FEE_POOL_ADDRESS \
          $ZERO_ADDRESS \
          0"
    deploy_contract "BAMM" "$constructor_args" "owner()(address)" "BAMM_ADDRESS" "../lib/b-protocol/packages/contracts/contracts/B.Protocol/"
    MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS=$DEPLOYED_ADDRESS
fi

# Deploy BLUSDToken contract
constructor_args="$BLUSD_NAME $BLUSD_SYMBOL"
deploy_contract "BLUSDToken" "$constructor_args" "owner()(address)" "BLUSD_TOKEN_ADDRESS"

BLUSD_TOKEN_ADDRESS=$DEPLOYED_ADDRESS
cast_call_wrapper $BLUSD_TOKEN_ADDRESS "name()(string)" ""
echo Name: $CALL_RESULT
cast_call_wrapper $BLUSD_TOKEN_ADDRESS "symbol()(string)" ""
echo Symbol: $CALL_RESULT
echo ""

# Deploy Egg NFT artwork
deploy_contract "GenerativeEggArtwork" "" "" "BOND_NFT_INITIAL_ARTWORK_ADDRESS" "NFTArtwork/"
BOND_NFT_INITIAL_ARTWORK_ADDRESS=$DEPLOYED_ADDRESS

# Deploy BondNFT contract
LIQUITY_DATA_ADDRESSES="(\
$MAINNET_LIQUITY_TROVE_MANAGER_ADDRESS,$MAINNET_LQTY_TOKEN_ADDRESS,$MAINNET_LIQUITY_STAKING_ADDRESS,\
$MAINNET_PICKLE_LQTY_JAR_ADDRESS,$MAINNET_PICKLE_LQTY_FARM_ADDRESS,\
$MAINNET_CURVE_GAUGE_CONTROLLER,$MAINNET_CURVE_GAUGE_LUSD_3CRV,$MAINNET_CURVE_GAUGE_LUSD_FRAX)"
constructor_args="$BOND_NFT_NAME $BOND_NFT_SYMBOL $BOND_NFT_INITIAL_ARTWORK_ADDRESS $BOND_NFT_LOCKOUT_PERIOD $LIQUITY_DATA_ADDRESSES"
deploy_contract "BondNFT" "$constructor_args" "owner()(address)" "BOND_NFT_ADDRESS"

BOND_NFT_ADDRESS=$DEPLOYED_ADDRESS
cast_call_wrapper $BOND_NFT_ADDRESS "name()(string)" ""
echo Name: $CALL_RESULT
cast_call_wrapper $BOND_NFT_ADDRESS "symbol()(string)" ""
echo Symbol: $CALL_RESULT
echo ""

# Create bLUSD AMM pool
deployment_arguments="$CURVE_V2_NAME $CURVE_V2_SYMBOL [$BLUSD_TOKEN_ADDRESS,$MAINNET_LUSD_3CRV_TOKEN_ADDRESS] \
$CURVE_V2_A $CURVE_V2_GAMMA $CURVE_V2_MID_FEE $CURVE_V2_OUT_FEE $CURVE_V2_ALLOWED_EXTRA_PROFIT $CURVE_V2_FEE_GAMMA \
$CURVE_V2_ADJUSTMENT_STEP $CURVE_V2_ADMIN_FEE $CURVE_V2_MA_HALF_TIME $CURVE_V2_INITIAL_PRICE"
deploy_from_factory \
    $MAINNET_CURVE_V2_FACTORY_ADDRESS \
    "deploy_pool(string,string,address[2],uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)(address)" \
    "$deployment_arguments" \
    "BLUSD_AMM_ADDRESS" \
    "bLUSD/LUSD-3CRV Curve AMM pool"

BLUSD_AMM_ADDRESS=$DEPLOYED_ADDRESS

# Create bLUSD AMM staking reward contract
deployment_arguments="$BLUSD_AMM_ADDRESS $DEPLOYER_ADDRESS"
deploy_from_factory \
    $MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS \
    "deploy_gauge(address,address)(address)" \
    "$deployment_arguments" \
    "BLUSD_AMM_STAKING_ADDRESS" \
    "bLUSD/LUSD-3CRV staking reward contract (Curve gauge)"

BLUSD_AMM_STAKING_ADDRESS=$DEPLOYED_ADDRESS

# Deploy ChickenBondManager contract
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

constructor_args="$EXTERNAL_ADDRESSES $PARAMS"
deploy_contract "ChickenBondManager" "$constructor_args" "getPendingLUSD()(uint256)" "CHICKEN_BOND_MANAGER_ADDRESS"

CHICKEN_BOND_MANAGER_ADDRESS=$DEPLOYED_ADDRESS

# Connect ChickenBond contracts
echo "Connecting BondNFT to ChickenBondManager..."
cast_send_wrapper $BOND_NFT_ADDRESS "setAddresses(address)" "$CHICKEN_BOND_MANAGER_ADDRESS"

echo "Connecting BLUSDToken to ChickenBondManager..."
cast_send_wrapper $BLUSD_TOKEN_ADDRESS "setAddresses(address)" "$CHICKEN_BOND_MANAGER_ADDRESS"

echo "Adding LUSD reward token for bLUSD/LUSD LPs, and set ChickenBondManager as distributor in Curve gauge..."
cast_send_wrapper \
    $MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS \
    "add_reward(address,address,address)" \
    "$BLUSD_AMM_STAKING_ADDRESS $MAINNET_LUSD_TOKEN_ADDRESS $CHICKEN_BOND_MANAGER_ADDRESS"

echo "Checking if BAMM is already initialized..."
cast_call_wrapper $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS "chicken()(address)" ""
if [[ $CALL_STATUS == 0 && $CALL_RESULT == $ZERO_ADDRESS ]]; then
    echo "Checking if we are owner of BAMM..."
    cast_call_wrapper $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS "isOwner()(bool)" ""
    if [[ $CALL_STATUS == 0 && $CALL_RESULT == true ]]; then
        echo "Connecting ChickenBondManager to BAMM..."
        cast_send_wrapper $MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS "setChicken(address)" "$CHICKEN_BOND_MANAGER_ADDRESS"
    else
        echo -e "Not owning B.AMM. Skipping connection to CBM..."
    fi
else
    echo -e "B.AMM already connected to CBM. Skipping..."
fi

echo -e "${GREEN}Finished.\n"
echo -e "${RESET_COLOR}"

echo -e $DEPLOYMENT_TXS

# Finish and save deployment addresses json
DEPLOYMENT_ADDRESSES="{${DEPLOYMENT_ADDRESSES::-1}}"
#echo -e "${DEPLOYMENT_ADDRESSES}\n"

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

echo $DEPLOYMENT_ADDRESSES | $PYTHON_CMD -m json.tool > $OUTPUT_FILE

cat $OUTPUT_FILE

