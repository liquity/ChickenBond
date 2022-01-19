from functools import reduce

def log_system(chicken, token, stoken):
    coop_bal = chicken.coop_token_balance()
    pol_bal = chicken.pol_token_balance()
    amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
    print(f"")
    print("Chicken Bonds state")
    #print(f" - Outstanding debt: {chicken.outstanding_debt:,.2f}")
    print(f" - Coop {token.symbol}:       {coop_bal:,.2f}")
    print(f" - POL {token.symbol}:        {pol_bal:,.2f}")
    print(f" - AMM {token.symbol} value:  {amm_value:,.2f}")
    print(f" - {stoken.symbol} supply:    {stoken.total_supply:,.2f}")
    if stoken.total_supply > 0:
        print(f" - POL ratio     (| no AMM): {(pol_bal + amm_value) / stoken.total_supply:,.2f}   |   {pol_bal / stoken.total_supply:,.2f}")
        print(f" - Reserve ratio (| no AMM): {(coop_bal + pol_bal + amm_value) / stoken.total_supply:,.2f}   |   {(coop_bal + pol_bal) / stoken.total_supply:,.2f}")
    print(f"")
    print(f"AMM pool:")
    print(f"{chicken.amm}")
    print(f" - AMM APR: {chicken.amm_iteration_apr:.3%}")
    print(f"")
    return

def log_user_balances(chicken, user, tokens):
    print(f"User {user.account}:")
    for token in tokens:
        print(f" - {token.symbol} balance: {token.balance_of(user.account):,.2f}")
    print(f" - Total balance: {reduce(lambda total, token: total + token.balance_of(user.account), tokens, 0.0):,.2f}")

    print("")
    return

def log_users(chicken, users, tokens):
    for user in users:
        log_user_balances(chicken, user, tokens)
    return

def log_state(chicken, chicks):
    log_system(chicken, chicken.token, chicken.stoken)
    #log_users(chicken, chicks, [chicken.token, chicken.stoken])
    return
