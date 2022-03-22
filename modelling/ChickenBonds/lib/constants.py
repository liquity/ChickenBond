# ------------ ITERATIONS AND TIME UNITS -----------------
TIME_UNITS_PER_YEAR = 360
MONTH = int(TIME_UNITS_PER_YEAR / 12)   # Months per year
YEAR = TIME_UNITS_PER_YEAR              # Days per year
ITERATIONS = TIME_UNITS_PER_YEAR * 4    # Total iterations steps in days

# ------------ Bootstrap -----------------
BOOTSTRAP_ITERATION = 10               # Iteration at which first bonders will chicken in to bootstrap the system
BOOTSTRAP_NUM_BONDS = 0                # Number of bonds for bootstrap

# ------------ Plots -----------------
PLOTS_SHOW = True                       # Whether to open browser tabs to show plots
PLOTS_SAVE = False                      # Whether to save plots in images/ folder
PLOTS_PREFIX = '001'                    # Prefix for plot files in case of saving
PLOTS_INTERVAL = [0, 0]                 # [0, 0] will plot’em all

# ------------ Logs -----------------
LOG_LEVEL = 0                           # To display logs in console (for now only 0: off, and 1: on)

# ------------- User and Money --------------------
NUM_CHICKS =   100
NUM_REBONDERS = 30     # Number of users that will rebond upon chickening in
NUM_LPS =       40     # Number of users that will provide liquidity upon chickening in
INITIAL_AMOUNT = 10000

# -------------- Bonding Parameters ----------------
EXTERNAL_YIELD = 0.05 # 5%              # Yield received from staking the total reserves per year.
BOND_AMOUNT = (100, 1000)               # Random number between 100 and 1,000.

# -------------- Controller Parameters -------------
INITIAL_ACCRUAL_PARAM = 30              # "u" in the accrual curve "t / (t + u)". The higher the value, the slower the accrual.
ACCRUAL_ADJUSTMENT_RATE = 0.01          # Set to non-zero to enable control
TARGET_AVERAGE_AGE = 30

# number of iterations to take the average APR of the AMM
AMM_APR_PERIOD = 10
AMM_FEE = 0.3 / 100                      # ToDo
MAX_SLIPPAGE = 0.10                     # ToDo
AMM_YIELD = 0.02                        # ToDo

# -------------- Natural Rates ---------------------
INITIAL_NATURAL_RATE = 0.05             # ToDo
SD_NATURAL_RATE = 0.002                 # ToDo

# -------------- Chicken Parameters ----------------
CHICKEN_IN_GAMMA = (1.5, 0.1)           # Parameters of gamma distribution for random target return (Mean: 1.5 * 0.1)
CHICKEN_OUT_PROBABILITY = 0.01          # Probability of a user randomly chicken out

# -------------- Price Parameters ----------------
# Initial price of sLQTY quoted in LQTY, to make sure bootstrap is profitable
INITIAL_PRICE = 1.2 * (BOOTSTRAP_ITERATION + INITIAL_ACCRUAL_PARAM) / BOOTSTRAP_ITERATION

PRICE_PREMIUM = "full_balance"            # The estimator of the price premium ("normal_dist","perpetuity","coop_balance","full_balance")
PREMIUM_MU = 0.1                        # Expected value of the normal distribution as a fraction of POL token balance
PREMIUM_SIGMA = 0.1                     # Deviation of the normal distribution as a fraction of the POL token balance

PRICE_VOLATILITY = "None"               # Risk estimator of the price ("None", "bounded", "unbounded")
VOLA_MU = 0                             # Expected value of a normal dist. for the volatility of price
VOLA_SIGMA = 1                          # Std. deviation of the normal dist of the volatility of the price

TWAP_PERIOD = 20                        # Average price of sLQTY over xx periods
