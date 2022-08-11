from functools import reduce

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
    print(f"Accrual param:   {tester.accrual_param:,.2f}")
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
    print(f" - AMM APR: {chicken.amm_iteration_apr:.3%}")
    return

def log_chick_balances(chicken, chick):
    token_bal = chicken.token.balance_of(chick.account)
    btkn_bal = chicken.btkn.balance_of(chick.account)
    btkn_value = chicken.btkn.balance_of(chick.account) * chicken.amm.get_token_B_price()
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

def log_state(chicken, chicks, tester, log_level=1, iteration=0):
    if log_level == 0:
        return
    print(f"\n\033[31m  --> Iteration {iteration}")
    print("  -------------------\033[0m\n")
    log_system(chicken, tester)
    log_amm(chicken)
    log_btkn_amm(chicken)
    #log_chicks(chicken, chicks)
    print("")
    return
