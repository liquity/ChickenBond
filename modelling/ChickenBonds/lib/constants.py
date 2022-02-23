# ------------ ITERATIONS AND TIME UNITS -----------------
TIME_UNITS_PER_YEAR = 360
MONTH = int(TIME_UNITS_PER_YEAR / 12)   # Months per year
YEAR = TIME_UNITS_PER_YEAR              # Days per year
ITERATIONS = TIME_UNITS_PER_YEAR * 4    # Total iterations steps in days

# ------------ Bootstrap -----------------
BOOTSTRAP_ITERATION = 10                # Iteration at which first bonders will chicken in to bootstrap the system
BOOTSTRAP_NUM_BONDS = 0                # Number of bonds for bootstrap

# ------------ Plots -----------------
PLOTS_SHOW = True                       # Whether to open browser tabs to show plots
PLOTS_SAVE = False                      # Whether to save plots in images/ folder
PLOTS_PREFIX = '001'                    # Prefix for plot files in case of saving
PLOTS_INTERVAL = [0, 0]                 # [0, 0] will plot’em all

# ------------ Logs -----------------
LOG_LEVEL = 0                           # To display logs in console (for now only 0: off, and 1: on)

# ------------- User and Money --------------------
NUM_CHICKS = 100
NUM_ACTIVE_CHICKS_PER_STEP = int(NUM_CHICKS / 10)
INITIAL_AMOUNT = 10000
NUM_REBONDERS = int(NUM_CHICKS / 2)     # Number of users that will rebond upon chickening in
NUM_LPS = int((NUM_CHICKS - NUM_REBONDERS) / 2)         # Number of users that will provide liquidity upon chickening in

# -------------- Bonding Parameters ----------------
BOND_STOKEN_ISSUANCE_RATE = 0.002       # New sLQTY minted per iteration as a fraction of the bonded amount.
EXTERNAL_YIELD = 0.05 # 5%              # Yield received from staking the total reserves per year.
BOND_PROBABILITY = [0.05, 0.01, 0]                 # 5% of the not bonded users bond each iteration
BOND_AMOUNT = (100, 1000)               # Random number between 100 and 1,000.

# number of iterations to take the average APR of the AMM
AMM_APR_PERIOD = 10
AMM_FEE = 0.04 / 100                    # ToDo
MAX_SLIPPAGE = 0.03                     # ToDo
AMM_YIELD = 0.02                        # ToDo
AMM_ARBITRAGE_DIVERGENCE = 0.05         # ToDo
REDEMPTION_ARBITRAGE_DIVERGENCE = 0.05  # ToDo

# -------------- Natural Rates ---------------------
INITIAL_NATURAL_RATE = 0.05             # ToDo
SD_NATURAL_RATE = 0.002                 # ToDo

# -------------- Chicken Parameters ----------------
CHICKEN_IN_GAMMA = (1.5, 0.1)           # Parameters of gamma distribution for random target return (Mean: 1.5 * 0.1)
CHICKEN_OUT_PROBABILITY = 0.05          # Probability of a user randomly chicken out
CHICKEN_UP_PROBABILITY = 0.2            # Probability of a user over in profit range to chicken-up

# -------------- Price Parameters ----------------
# Initial price of sLQTY quoted in LQTY, to make sure bootstrap is profitable
INITIAL_PRICE = 1.2 * (BOOTSTRAP_ITERATION + 1) / BOOTSTRAP_ITERATION

PRICE_PREMIUM = "coop_balance"            # The estimator of the price premium ("normal_dist","perpetuity","coop_balance")
PREMIUM_MU = 0.1                        # Expected value of the normal distribution as a fraction of POL token balance
PREMIUM_SIGMA = 0.1                     # Deviation of the normal distribution as a fraction of the POL token balance

PRICE_VOLATILITY = "None"               # Risk estimator of the price ("None", "bounded", "unbounded")
VOLA_MU = 0                             # Expected value of a normal dist. for the volatility of price
VOLA_SIGMA = 1                          # Std. deviation of the normal dist of the volatility of the price

TWAP_PERIOD = 20                        # Average price of sLQTY over xx periods
