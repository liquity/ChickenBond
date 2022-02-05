
# ------------ ITERATIONS AND TIME UNITS -----------------
TIME_UNITS_PER_YEAR = 360
MONTH = int(TIME_UNITS_PER_YEAR / 12)   # Months per year
YEAR = TIME_UNITS_PER_YEAR              # Days per year
ITERATIONS = TIME_UNITS_PER_YEAR * 4    # Total iterations steps in days
PLOT_INTERVAL = [0, 0]                  # [0, 0] will plot’em all


# ------------- User and Money --------------------
NUM_CHICKS = 100
NUM_ACTIVE_CHICKS_PER_STEP = int(NUM_CHICKS / 10)
INITIAL_AMOUNT = 10000

# -------------- Bonding Parameters ----------------
BOND_STOKEN_ISSUANCE_RATE = 0.002       # New sLQTY minted per iteration as a fraction of the POL pool.
EXTERNAL_YIELD = 0.05 # 5%              # Yield received from staking the total reserves per year.
BOND_PROBABILITY = 0.05                 # 5% of the not bonded users bond each iteration
BOND_AMOUNT = (100, 1000)               # Random number between 100 and 1,000.

# -------------- Price Parameters ----------------
INITIAL_PRICE = 19.0                    # Initial price of sLQTY quoted in LQTY

PRICE_PREMIUM = "perpetuity"            # The estimator of the price premium ("normal_dist","perpetuity","coop_balance")
premium_mu = 0.1                        # Expected value of the normal distribution as a fraction of POL token balance
premium_sigma = 0.1                     # Deviation of the normal distribution as a fraction of the POL token balance

PRICE_VOLATILITY = "None"               # Risk estimator of the price ("None", "bounded", "unbounded")
vola_mu = 0                             # Expected value of a normal dist. for the volatility of price
vola_sigma = 1                          # Std. deviation of the normal dist of the volatility of the price

TWAP_PERIOD = 20                        # Average price of sLQTY over xx periods


#BORROWING_FEE = 0.005 # 0.5%

# number of iterations to take the average APR of the AMM
AMM_APR_PERIOD = 10
AMM_FEE = 0.04 / 100                    # ToDo
MAX_SLIPPAGE = 0.03                     # ToDo
AMM_ARBITRAGE_DIVERGENCE = 0.05         # ToDo
REDEMPTION_ARBITRAGE_DIVERGENCE = 0.05  # ToDo

# -------------- Natural Rates ---------------------
INITIAL_NATURAL_RATE = 0.05             # ToDo
SD_NATURAL_RATE = 0.002                 # ToDo

# -------------- Chicken Parameters ----------------
CHICKEN_IN_GAMMA = (1.5, 0.1)           # Parameters of gamma distribution for random target return (Mean: 1.5 * 0.1)
CHICKEN_OUT_PROBABILITY = 0.05          # Probability of a user randomly chicken out
CHICKEN_UP_PROBABILITY = 0.2            # Probability of a user over in profit range to chicken-up
CHICKEN_IN_AMM_SHARE = 0.2              # ToDo
