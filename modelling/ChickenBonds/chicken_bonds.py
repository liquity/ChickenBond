import os
import numpy as np

from lib.constants import *
from lib.erc_token import *
from lib.chicken import *
from lib.utils import *
from lib.state import *
from lib.user import *
from lib.testers import *
from lib.log import *
from lib.plots import *

def deploy():
    coll = Token('COLL')
    lqty = Token('LQTY')
    slqty = Token('sLQTY')

    chicken = Chicken(coll, lqty, slqty, "Coop", "POL", "AMM", AMM_FEE)

    chicks = list(map(lambda chick: User(f"chick_{chick:02}"), range(NUM_CHICKS)))
    # Initial CHICK balance
    for chick in chicks:
        lqty.mint(chick.account, INITIAL_AMOUNT)

    borrower = User("borrower")
    #lqty.mint(borrower.account, INITIAL_AMOUNT)
    return chicken, chicks, borrower

def main(tester):
    if not os.path.exists("images"):
        os.mkdir("images")

    chicken, chicks, borrower = deploy()

    data = init_data()
    natural_rate = INITIAL_NATURAL_RATE
    accrued_fees_A = 0
    accrued_fees_B = 0

    print(f"\n  --> Model: {tester.name}")
    print('  ------------------------------------------------------\n')
    log_state(chicken, chicks)

    tester.init(chicks)

    for iteration in range(ITERATIONS):
        print(f"\n\033[31m  --> Iteration {iteration}")
        print("  -------------------\033[0m\n")

        natural_rate = tester.get_natural_rate(natural_rate, iteration)
        chicken.amm_iteration_apr, accrued_fees_A, accrued_fees_B = get_amm_iteration_apr(chicken, accrued_fees_A, accrued_fees_B)
        chicken.amm_average_apr = get_amm_average_apr(data, iteration)
        #print(f"AMM iteration APR: {chicken.amm_iteration_apr:.3%}")
        #print(f"AMM average APR: {chicken.amm_average_apr:.3%}")
        #assert chicken.amm_iteration_apr >= 0

        # Distribute yield
        tester.distribute_yield(chicken, chicks, iteration)

        # Users bond
        tester.bond(chicken, chicks, iteration)

        # Users chicken in and out
        tester.chicken_in_out(chicken, chicks, data, iteration)

        # Provide and withdraw liqudity to/from AMM
        tester.adjust_liquidity(chicken, chicks, chicken.amm_average_apr, iteration)

        # If price is low, buy from AMM and stake
        tester.amm_arbitrage(chicken, chicks, iteration)

        # If price is below redemption price, redeem and buy
        tester.redemption_arbitrage(chicken, chicks, iteration)

        log_state(chicken, chicks)

        new_row = state_to_row(
            chicken,
            tester,
            natural_rate,
            data,
            iteration
        )
        data = data.append(new_row, ignore_index=True)

        if PLOT_INTERVAL[1] > 0 and iteration > PLOT_INTERVAL[1]:
            break

    plot_interval = PLOT_INTERVAL[:]
    group=90
    group_description="Quarter"
    if PLOT_INTERVAL[1] > 0:
        group = 1
        group_description = "Day"
    else:
        plot_interval[1] = ITERATIONS

    log_state(chicken, chicks)

    #print(data)
    #"""
    plot_charts(
        chicken,
        chicks,
        data[plot_interval[0] : plot_interval[1]],
        tester.price_max_value, tester.apr_max_value,
        description=tester.name,
        group=group,
        group_description=group_description,
        show=True,
        save=True,
        global_prefix="001",
        tester_prefixes_getter = tester.prefixes_getter
    )
    #"""
    return

if __name__ == "__main__":
    main(TesterIssuanceBonds())
    main(TesterIssuanceBondsAMM_1())
    main(TesterIssuanceBondsAMM_2())
    main(TesterIssuanceBondsAMM_3())
    main(TesterRebonding())          # Approach 2 + Rebonding
