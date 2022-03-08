from functools import reduce

def log_system(chicken, tester):
    token = chicken.token
    stoken = chicken.stoken
    coop_bal = chicken.coop_token_balance()
    pol_bal = chicken.pol_token_balance()
    amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
    print(f"")
    print("Chicken Bonds state")
    #print(f" - Outstanding debt: {chicken.outstanding_debt:,.2f}")
    print(f" - Pending {token.symbol}:               {coop_bal:,.2f}")
    print(f" - Acquired {token.symbol}:              {pol_bal:,.2f}")
    print(f" - Permanent (DEX) {token.symbol} value: {amm_value:,.2f}")
    print(f" - {stoken.symbol} supply:               {stoken.total_supply:,.2f}")
    if stoken.total_supply > 0:
        print(f" - Backing ratio (| no AMM): {chicken.get_pol_ratio_with_amm():,.2f}   |   {chicken.get_pol_ratio_no_amm():,.2f}")
        print(f" - Reserve ratio (| no AMM): {chicken.get_reserve_ratio_with_amm():,.2f}   |   {chicken.get_reserve_ratio_no_amm():,.2f}")

    print("")
    print(f"Fair price:      {tester.get_fair_price(chicken):,.2f}")
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
    print(f" - AMM APR: {chicken.amm_iteration_apr:.3%}")
    return

def log_stoken_amm(chicken):
    log_amm_pool(chicken.stoken_amm, "sTOKEN AMM")
    return

def log_chick_balances(chicken, chick):
    token_bal = chicken.token.balance_of(chick.account)
    stoken_bal = chicken.stoken.balance_of(chick.account)
    stoken_value = chicken.stoken.balance_of(chick.account) * chicken.amm.get_token_B_price()
    print("")
    print(f"User {chick.account}:")
    print(f" - {chicken.token.symbol} balance: {token_bal:,.2f}")
    print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
    print(f" - {chicken.stoken.symbol} balance: {stoken_bal:,.2f}")
    print(f" - {chicken.stoken.symbol} value:   {stoken_value:,.2f}")
    print(f" - Total value: {token_bal + chick.bond_amount + stoken_value:,.2f}")
    return

def log_chicks(chicken, chicks, tokens):
    for chick in chicks:
        log_chick_balances(chicken, chick)
    return

def log_state(chicken, chicks, tester, log_level=1):
    if log_level == 0:
        return
    log_system(chicken, tester)
    log_amm(chicken)
    log_stoken_amm(chicken)
    #log_chicks(chicken, chicks)
    print("")
    return
