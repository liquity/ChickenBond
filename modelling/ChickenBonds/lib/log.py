from functools import reduce

from lib.utils import *

def log_system(chicken, tester):
    token = chicken.token
    btkn = chicken.btkn
    pending_bal = chicken.pending_token_balance()
    reserve_bal = chicken.reserve_token_balance()
    amm_value = chicken.amm.get_value_in_token_A_of(chicken.reserve_account)
    print(f"")
    print("Chicken Bonds state")
    #print(f" - Outstanding debt: {chicken.outstanding_debt:,.2f}")
    print(f" - Pending {token.symbol}:               {pending_bal:,.2f}")
    print(f" - Reserve {token.symbol}:               {reserve_bal:,.2f}")
    print(f" - Permanent (DEX) {token.symbol} value: {amm_value:,.2f}")
    print(f" - {btkn.symbol} supply:               {btkn.total_supply:,.2f}")
    if btkn.total_supply > 0:
        print(f" - Backing ratio:              {chicken.get_backing_ratio():,.2f}")

    print("")
    print(f"Fair price:      {tester.get_fair_price(chicken):,.2f}")
    print(f"Accrual param:   {tester.accrual_param:,.6f}")
    print(f"Rebond Time:     {tester.get_rebond_time(chicken):,.2f}")
    print(f"Chicken in Time: {tester.get_optimal_apr_chicken_in_time(chicken):,.2f}")
    return

def log_amm_pool(amm, name):
    print(f"")
    print(f"{name} pool:")
    print(f"{amm}")
    return

def log_amm(chicken):
    log_amm_pool(chicken.amm, "AMM")
    return

def log_btkn_amm(chicken):
    log_amm_pool(chicken.btkn_amm, "bTKN AMM")
    print(f" - {chicken.btkn_amm.token_A.symbol} Fees: {chicken.btkn_amm.fees_accrued_A:,.2f}")
    print(f" - {chicken.btkn_amm.token_B.symbol} Fees: {chicken.btkn_amm.fees_accrued_B:,.2f}")
    print(f" - {chicken.btkn_amm.lp_token.symbol} Fees: {chicken.btkn_amm.fees_accrued_LP:,.2f}")
    print(f" - AMM APR: {chicken.amm_iteration_apr:.3%}")
    return

def log_chick_balances(chicken, chick):
    token_bal = chicken.token.balance_of(chick.account)
    btkn_bal = chicken.btkn.balance_of(chick.account)
    btkn_value = chicken.btkn.balance_of(chick.account) * chicken.btkn_amm.get_token_B_price()
    amm_value = chicken.btkn_amm.get_value_in_token_A_of(chick.account)
    print("")
    print(f"User {chick.account}:")
    print(f" - {chicken.token.symbol} balance:  {token_bal:,.2f}")
    print(f" - {chicken.token.symbol} bonded:   {chick.bond_amount:,.2f}")
    print(f" - {chicken.btkn.symbol} balance: {btkn_bal:,.2f}")
    print(f" - {chicken.btkn.symbol} value:   {btkn_value:,.2f}")
    print(f" - AMM value:     {amm_value:,.2f}")
    print(f" - Total value: {token_bal + chick.bond_amount + btkn_value + amm_value:,.2f}")
    return

def log_btkn_balances(chicken, chicks):
    chicks.sort(key = lambda c: c.account)
    print("")
    print(f"{chicken.btkn.symbol} balances:")
    total_btkn = 0
    for chick in chicks:
        chick_bal = chicken.btkn.balance_of(chick.account)
        if chick_bal > 0:
            print(f"{chick.account}: {chick_bal:,.2f}")
        total_btkn = total_btkn + chick_bal
    print(f"Total : {total_btkn:,.2f}")
    return

def log_chicks(chicken, chicks):
    for chick in chicks:
        log_chick_balances(chicken, chick)
    return

def get_subgroup_total_value(chicken, chicks, chick_selector):
    return reduce(
        lambda total, chick: total + get_chick_total_token_value(chicken, chick),
        filter(chick_selector, chicks),
        0
    )

def log_performance(chicken, chicks):
    print("")
    print("Performance")
    print("")
    pending_bal = chicken.pending_token_balance()
    reserve_bal = chicken.reserve_token_balance()
    amm_value = chicken.amm.get_value_in_token_A_of(chicken.reserve_account)
    print(f" - Total permament:               {amm_value:,.2f}")
    print(f" - Permament percentage:          {amm_value / (pending_bal + reserve_bal + amm_value):.3%}")
    print("")
    total_rebonders = get_subgroup_total_value(chicken, chicks, lambda chick: chick.rebonder)
    total_lps = get_subgroup_total_value(chicken, chicks, lambda chick: chick.lp)
    total_sellers = get_subgroup_total_value(chicken, chicks, lambda chick: chick.seller)
    total_traders = get_subgroup_total_value(chicken, chicks, lambda chick: chick.trader)
    print(f" - Rebonders avg gain: {total_rebonders / (NUM_REBONDERS * INITIAL_AMOUNT) - 1 :.3%}")
    print(f" - LPs avg gain:       {total_lps / (NUM_LPS * INITIAL_AMOUNT) - 1 :.3%}")
    print(f" - Sellers avg gain:   {total_sellers / (NUM_SELLERS * INITIAL_AMOUNT) - 1 :.3%}")
    print(f" - Traders avg gain:   {total_traders / (NUM_TRADERS * INITIAL_AMOUNT) - 1 :.3%}")

    # Total LQTY
    total_lqty = reduce(
        lambda total, chick: total + chicken.token.balance_of(chick.account),
        chicks,
        0
    )
    total_lqty += chicken.pending_token_balance()
    total_lqty += chicken.reserve_token_balance()
    total_lqty += chicken.amm.get_value_in_token_A_of(chicken.reserve_account)
    total_lqty += chicken.token.balance_of(chicken.btkn_amm.pool_account)
    total_lqty += chicken.token.balance_of(chicken.btkn_amm.rewards.account)
    print("")
    print(f" - Total LQTY:         {total_lqty:,.2f}")
    #print(f" - Yield generated:    {total_lqty / (NUM_CHICKS * INITIAL_AMOUNT) - 1:.3%}")



    return

def log_state(chicken, chicks, tester, log_level=1, iteration=0):
    if log_level == 0:
        return
    print(f"\n\033[31m  --> Iteration {iteration}")
    print("  -------------------\033[0m\n")
    log_system(chicken, tester)
    #log_amm(chicken)
    log_btkn_amm(chicken)
    #log_chicks(chicken, chicks)
    log_performance(chicken, chicks)
    print("")
    return
