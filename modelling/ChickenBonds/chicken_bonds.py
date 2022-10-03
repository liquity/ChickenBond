import os
import numpy as np

from lib.constants import *
from lib.chicken import *
from lib.controllers import *
from lib.utils import *
from lib.state import *
from lib.user import *
from lib.testers import *
from lib.log import *
from lib.plots import *

def deploy():
    coll = Token('ETH')
    lqty = Token('LQTY')
    blqty = Token('bLQTY')

    chicken = Chicken(
        coll, lqty, blqty,
        "Pending", "RESERVE",
        "AMM", AMM_FEE,
        "bTKN_AMM", AMM_FEE,
        "Rewards", REWARDS_PERIOD,
        # Curve V2:
        CURVE_V2_A,
        CURVE_V2_GAMMA,
        CURVE_V2_MID_FEE,
        CURVE_V2_OUT_FEE,
        CURVE_V2_ALLOWED_EXTRA_PROFIT,
        CURVE_V2_FEE_GAMMA,
        CURVE_V2_ADJUSTMENT_STEP,
        CURVE_V2_ADMIN_FEE,
        CURVE_V2_MA_HALF_TIME,
        CURVE_V2_INITIAL_PRICE
    )

    chicks = list(map(lambda chick: User(f"chick_{chick:02}"), range(NUM_CHICKS)))
    # Initial CHICK balance
    for chick in chicks:
        lqty.mint(chick.account, INITIAL_AMOUNT)

    return chicken, chicks

def main(tester):
    if not os.path.exists("images"):
        os.mkdir("images")

    #print(f"alpha: {INITIAL_ACCRUAL_PARAM}")

    chicken, chicks = deploy()

    controller = AsymmetricController(
        adjustment_rate=ACCRUAL_ADJUSTMENT_RATE,
        init_output=INITIAL_ACCRUAL_PARAM
    )

    data = init_data()
    natural_rate = INITIAL_NATURAL_RATE
    accrued_fees_A = 0
    accrued_fees_B = 0
    accrued_fees_LP = 0

    print(f"\n  --> Model: {tester.name}")
    print('  ------------------------------------------------------\n')
    log_state(chicken, chicks, tester, LOG_LEVEL, 0)

    tester.init(chicks)

    for iteration in range(ITERATIONS):
        #print(f"\n  --> Iteration: {iteration}")

        chicken.btkn_amm.set_block_timestamp(iteration)

        natural_rate = tester.get_natural_rate(natural_rate, iteration)
        chicken.amm_iteration_apr, accrued_fees_A, accrued_fees_B, accrued_fees_LP = get_amm_iteration_apr(
            chicken.btkn_amm, accrued_fees_A, accrued_fees_B, accrued_fees_LP
        )
        chicken.amm_average_apr = get_amm_average_apr(data, iteration)
        #print(f"AMM iteration APR: {chicken.amm_iteration_apr:.3%}")
        #print(f"AMM average APR: {chicken.amm_average_apr:.3%}")
        #assert chicken.amm_iteration_apr >= 0

        # Distribute yield
        tester.distribute_yield(chicken, chicks, iteration)

        # Users bond
        tester.bond(chicken, chicks, iteration)

        # Users chicken in and out
        tester.update_chicken(chicken, chicks, data, iteration, LOG_LEVEL > 0)

        # Arbitrage bTKN
        tester.arbitrage_btkn(chicken, chicks, iteration, LOG_LEVEL > 0)

        # Buy bTKN (speculation if price is low)
        tester.buy_btkn(chicken, chicks, LOG_LEVEL > 0)

        # Sell bTKN (speculation if they are making gains)
        tester.sell_btkn(chicken, chicks, LOG_LEVEL > 0)

        # Controller feedback
        avg_age = tester.get_avg_outstanding_bond_age(chicks, iteration)
        controller_output = controller.feed(TARGET_AVERAGE_AGE - avg_age)
        tester.set_accrual_param(controller_output)

        log_state(chicken, chicks, tester, LOG_LEVEL, iteration)

        new_row = state_to_row(
            chicken,
            tester,
            natural_rate,
            avg_age,
            data,
            iteration
        )
        data = data.append(new_row, ignore_index=True)

        if PLOTS_INTERVAL[1] > 0 and iteration >= PLOTS_INTERVAL[1]:
            break
        if chicken.btkn_amm.get_token_B_price() > 100:
            print(f"Price too high!: {chicken.btkn_amm.get_token_B_price():,.2f}")
            break

    plot_interval = PLOTS_INTERVAL[:]
    group=90
    group_description="Quarter"
    if PLOTS_INTERVAL[1] > 0:
        group = 1
        group_description = "Day"
    else:
        plot_interval[1] = ITERATIONS

    log_state(chicken, chicks, tester, 1, 'END')

    plot_charts(
        chicken,
        chicks,
        data[plot_interval[0] : plot_interval[1]],
        tester.price_max_value, tester.time_max_value, tester.apr_min_value, tester.apr_max_value,
        description=tester.name,
        group=group,
        group_description=group_description,
        show=PLOTS_SHOW,
        save=PLOTS_SAVE,
        global_prefix=PLOTS_PREFIX,
        tester_prefixes_getter = tester.prefixes_getter
    )

    return

if __name__ == "__main__":
    main(TesterSimple())
