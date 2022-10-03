# ------------ ITERATIONS AND TIME UNITS -----------------
TIME_UNITS_PER_YEAR = 360
MONTH = int(TIME_UNITS_PER_YEAR / 12)   # Months per year
YEAR = TIME_UNITS_PER_YEAR              # Days per year
ITERATIONS = TIME_UNITS_PER_YEAR * 4    # Total iterations steps in days
#ITERATIONS = 360

# ------------ Plots -----------------
PLOTS_SHOW = True                       # Whether to open browser tabs to show plots
#PLOTS_SHOW = False
PLOTS_SAVE = False                      # Whether to save plots in images/ folder
PLOTS_PREFIX = '001'                    # Prefix for plot files in case of saving
PLOTS_INTERVAL = [0, 0]                 # [0, 0] will plot’em all

# ------------ Logs -----------------
LOG_LEVEL = 0                           # To display logs in console (for now only 0: off, and 1: on)

# ------------- User and Money --------------------
NUM_CHICKS =   100
NUM_REBONDERS = 25     # Number of users that will rebond upon chickening in
NUM_LPS =       25     # Number of users that will provide liquidity upon chickening in
NUM_SELLERS =   25     # Number of users that will sell upon chickening in
#NUM_TRADERS           # Number of users that will only trade (never bond)
NUM_TRADERS =   NUM_CHICKS - (NUM_REBONDERS + NUM_LPS + NUM_SELLERS)
INITIAL_AMOUNT = 10000

# -------------- Bonding Parameters ----------------
EXTERNAL_YIELD = 0.10 # 10%             # Yield received from staking the total reserves per year.
BOND_AMOUNT = (100, 1000)               # Random number between 100 and 1,000.

# ------------ Bootstrap -----------------
BOOTSTRAP_PERIOD_CHICKEN_IN = 7        # Iteration at which first bonders will chicken in to bootstrap the system
BOOTSTRAP_PERIOD_REDEEM = 7            # Iteration at which first bonders will chicken in to bootstrap the system
BOOTSTRAP_NUM_BONDS = 10               # Number of bonds for bootstrap

CHICKEN_IN_AMM_FEE = 0.03 # 3%         # Tax to be used for bTKN AMM rewards

# ------------- AMM params --------------
AMM_APR_PERIOD = 10                     # number of iterations to take the average APR of the AMM
AMM_FEE = 0.2 / 100                     # ToDo
MAX_SLIPPAGE = 0.10                     # ToDo
AMM_YIELD = 0.02                        # ToDo: remove and use real fees!
REWARDS_PERIOD = 7                      # Time to distribute current rewards
INITIAL_BTKN_PRICE = 1.5                # Initial price the first user to chicken in and LP to AMM will use
#INITIAL_BTKN_PRICE = 1.2 * (BOOTSTRAP_PERIOD_CHICKEN_IN + INITIAL_ACCRUAL_PARAM) / BOOTSTRAP_PERIOD_CHICKEN_IN

# ------------- Curve V2 params --------------
"""
# cvxFxs/Fxs: https://curve.fi/factory-crypto/18
CURVE_V2_A = 200000000 / 10**18
CURVE_V2_GAMMA = 19900000000000000 / 10**18
CURVE_V2_MID_FEE = 15000000 / 10**10
CURVE_V2_OUT_FEE = 30000000 / 10**10
CURVE_V2_ALLOWED_EXTRA_PROFIT = 100000000 / 10**18
CURVE_V2_FEE_GAMMA = 5000000000000000 / 10**18
CURVE_V2_ADJUSTMENT_STEP = 5500000000000 / 10**18
CURVE_V2_ADMIN_FEE = 5000000000 / 10**18
CURVE_V2_MA_HALF_TIME = 600
CURVE_V2_INITIAL_PRICE = INITIAL_BTKN_PRICE
"""
# Volatile recommendations
CURVE_V2_A = 400000 / 10**18
CURVE_V2_GAMMA = 145000000000000 / 10**18
CURVE_V2_MID_FEE = 26000000 / 10**10
CURVE_V2_OUT_FEE = 45000000 / 10**10
CURVE_V2_ALLOWED_EXTRA_PROFIT = 2000000000000 / 10**18
CURVE_V2_FEE_GAMMA = 230000000000000 / 10**18
CURVE_V2_ADJUSTMENT_STEP = 146000000000000 / 10**18
CURVE_V2_ADMIN_FEE = 5000000000 / 10**18
CURVE_V2_MA_HALF_TIME = 25
CURVE_V2_INITIAL_PRICE = INITIAL_BTKN_PRICE
#"""

FRACTION_TO_SWAP = 0.1 # 10%            # Fraction of token funds in pool to use for slippage measures

# -------------- Controller Parameters -------------
ACCRUAL_ADJUSTMENT_RATE = 0.01          # Set to non-zero to enable control
TARGET_AVERAGE_AGE = 30
#INITIAL_ACCRUAL_PARAM = 5.8            # "u" in the accrual curve "t / (t + u)". The higher the value, the slower the accrual.
                                        # alpha = T * [(1-fee)*lambda - 1] / [1 + ((1-fee)*lambda)^0.5]
INITIAL_ACCRUAL_PARAM = TARGET_AVERAGE_AGE  * ((1-CHICKEN_IN_AMM_FEE)*INITIAL_BTKN_PRICE - 1) / (1 + ((1-CHICKEN_IN_AMM_FEE)*INITIAL_BTKN_PRICE)**0.5)

# TODO
# -------------- Redemption Parameters ----------------
#REDEMPTION_FEE_BETA = 2                 # Parameter by which to divide the redeemed fraction, in order to calculate the new base rate from a redemption
#REDEMPTION_FEE_MINUTE_DECAY_FACTOR = 0.999037758833783000 # Factor by which redemption fee decays (exponentially) every minute
#MIN_BTKN_SUPPLY = 1                    # Minimum of bTKN left after a redemption

# -------------- Chicken Parameters ----------------
CHICKEN_IN_GAMMA = (1.5, 0.1)           # Parameters of gamma distribution for random target return (Mean: 1.5 * 0.1)
CHICKEN_OUT_PROBABILITY = 0.01          # Probability of a user randomly chicken out
# TODO: fix 'yield_comparison' to take into account the chicken in fee
CHICKEN_IN_LIQUIDITY_FACTOR = 0.3 #30%  # Except LPs, users won’t sell if the claimable amount is bigger than this proportion of the pool

# -------------- Buy bTKN Parameters ----------------
BUY_PREMIUM_PERCENTAGE_MEAN = 0.5 # Percentage of the premium that arbitrageurs will chase, on average
BUY_PREMIUM_PERCENTAGE_SD = 0.1   # Standard deviation for arbitrage premium percentage shock
BUY_PRICE_CAP = INITIAL_BTKN_PRICE * 2 # Max price that arbitrageurs would ever pay

# -------------- Natural Rates ---------------------
INITIAL_NATURAL_RATE = 0.05             # ToDo
SD_NATURAL_RATE = 0.002                 # ToDo

# -------------- Price Parameters ----------------
PRICE_PREMIUM = "full_balance"          # The estimator of the price premium ("normal_dist","perpetuity","pending_balance","full_balance", "yield_comparison")
PREMIUM_MU = 0.1                        # Expected value of the normal distribution as a fraction of RESERVE token balance
PREMIUM_SIGMA = 0.1                     # Deviation of the normal distribution as a fraction of the RESERVE token balance

PRICE_VOLATILITY = "None"               # Risk estimator of the price ("None", "bounded", "unbounded")
VOLA_MU = 0                             # Expected value of a normal dist. for the volatility of price
VOLA_SIGMA = 1                          # Std. deviation of the normal dist of the volatility of the price

TWAP_PERIOD = 20                        # Average price of bLQTY over xx periods


