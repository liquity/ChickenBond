# Contract addresses (Mainnet)
MAINNET_LUSD_TOKEN_ADDRESS="0x5f98805A4E8be255a32880FDeC7F6728C6568bA0"
MAINNET_LQTY_TOKEN_ADDRESS="0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D"
MAINNET_LIQUITY_SP_ADDRESS="0x66017D22b0f8556afDd19FC67041899Eb65a21bb"
MAINNET_LIQUITY_TROVE_MANAGER_ADDRESS="0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2"
MAINNET_LIQUITY_STAKING_ADDRESS="0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d"
MAINNET_PICKLE_LQTY_JAR_ADDRESS="0x65B2532474f717D5A8ba38078B78106D56118bbb"
MAINNET_PICKLE_LQTY_FARM_ADDRESS="0xA7BC844a76e727Ec5250f3849148c21F4b43CeEA"
MAINNET_3CRV_TOKEN_ADDRESS="0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490"
MAINNET_YEARN_CURVE_VAULT_ADDRESS="0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6"
MAINNET_CURVE_POOL_ADDRESS="0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA"
MAINNET_CURVE_BASEPOOL_ADDRESS="0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
MAINNET_BPROTOCOL_LUSD_BAMM_ADDRESS="0x9062d1477c3cD000301A471Be03c9dB85C3Fc27a"
MAINNET_YEARN_CURVE_VAULT_ADDRESS="0x5fA5B62c8AF877CB37031e0a3B2f34A78e3C56A6"
MAINNET_YEARN_REGISTRY_ADDRESS="0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804"
MAINNET_YEARN_GOVERNANCE_ADDRESS="0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52"
MAINNET_CURVE_V2_FACTORY_ADDRESS="0xF18056Bbd320E96A48e3Fbf8bC061322531aac99"
MAINNET_CURVE_V2_GAUGE_MANAGER_PROXY_ADDRESS="0xd05Ad7fb0CDb39AaAA1407564dad0EC78d30d564"
MAINNET_CURVE_GAUGE_CONTROLLER="0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"
MAINNET_CURVE_GAUGE_LUSD_3CRV="0x9B8519A9a00100720CCdC8a120fBeD319cA47a14"
MAINNET_CURVE_GAUGE_LUSD_FRAX="0x389Fc079a15354E9cbcE8258433CC0F85B755A42"

# BondNFT constructor arguments
BOND_NFT_NAME="LUSDBondNFT"
BOND_NFT_SYMBOL="LUSDBOND"
BOND_NFT_LOCKOUT_PERIOD=86400                               # 1 day

# bLUSD constructor arguments
BLUSD_NAME="Boosted LUSD"
BLUSD_SYMBOL="bLUSD"

# Curve V2 internal bLUSD/LUSD params
CURVE_V2_NAME="bLUSD_LUSD"
CURVE_V2_SYMBOL="bLUSDLUSDC"
CURVE_V2_A=400000
CURVE_V2_GAMMA=145000000000000                              # 0.000145
CURVE_V2_MID_FEE=26000000                                   # 0.26%
CURVE_V2_OUT_FEE=45000000                                   # 0.45%
CURVE_V2_ALLOWED_EXTRA_PROFIT=2000000000000                 # 0.000002
CURVE_V2_FEE_GAMMA=230000000000000                          # 0.00023
CURVE_V2_ADJUSTMENT_STEP=146000000000000                    # 0.000146
CURVE_V2_ADMIN_FEE=5000000000                               # 50%
CURVE_V2_MA_HALF_TIME=600
CURVE_V2_INITIAL_PRICE=666666666666666600                   # 0.66.. (1/1.5)

# ChickenBonds constructor arguments
INITIAL_ACCRUAL_PARAMETER=216000000000000000000000          # 2.5 days * 1e18
MINIMUM_ACCRUAL_PARAMETER=216000000000000000000             # 2.5 days * 1e18 / 1000
ACCRUAL_ADJUSTMENT_RATE=10000000000000000                   # 1e16 = 1%
TARGET_AVERAGE_AGE_SECONDS=2592000                          # 30 days
ACCRUAL_ADJUSTMENT_PERIOD_SECONDS=86400                     # 1 day
CHICKEN_IN_AMM_FEE=10000000000000000                        # 1e16 = 1%
CURVE_DEPOSIT_WITHDRAW_DYDX_THRESHOLD=1000400000000000000   # 10004e14 = 1.0004
BOOTSTRAP_PERIOD_CHICKEN_IN=604800                          # 7 days
BOOTSTRAP_PERIOD_REDEEM=604800                              # 7 days
BOOTSTRAP_PERIOD_SHIFT=7776000                              # 90 days
SHIFTER_DELAY=3600                                          # 1 hour
SHIFTER_WINDOW=600                                          # 10 minutes
MIN_BLUSD_SUPPLY=1000000000000000000                        # 1 bLUSD
MIN_BOND_AMOUNT=100000000000000000000                       # 100 LUSD
NFT_RANDOMNESS_DIVISOR=1000000000000000000000               # 1000
REDEMPTION_FEE_BETA=2
REDEMPTION_FEE_MINUTE_DECAY_FACTOR=999037758833783000       # 12 hour half life