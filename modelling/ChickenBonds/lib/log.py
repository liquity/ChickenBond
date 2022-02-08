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
    print(f" - Toll: {chicken.toll:.2%}")
    print(f"")
    print(f"AMM pool:")
    print(f"{chicken.amm}")
    print(f" - AMM APR: {chicken.amm_iteration_apr:.3%}")
    print(f"")
    return

def log_chick_balances(chicken, chick):
    token_bal = chicken.token.balance_of(chick.account)
    stoken_bal = chicken.stoken.balance_of(chick.account)
    stoken_value = chicken.stoken.balance_of(chick.account) * chicken.amm.get_token_B_price()
    print(f"User {chick.account}:")
    print(f" - {chicken.token.symbol} balance: {token_bal:,.2f}")
    print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
    print(f" - {chicken.stoken.symbol} balance: {stoken_bal:,.2f}")
    print(f" - {chicken.stoken.symbol} value:   {stoken_value:,.2f}")
    print(f" - Total value: {token_bal + chick.bond_amount + stoken_value:,.2f}")
    print("")
    return

def log_chicks(chicken, chicks, tokens):
    for chick in chicks:
        log_chick_balances(chicken, chick)
    return

def log_state(chicken, chicks):
    log_system(chicken, chicken.token, chicken.stoken)
    #log_chicks(chicken, chicks)
    return
