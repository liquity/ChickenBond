from lib.constants import *

def get_amm_iteration_apr(amm, previous_accrued_fees_A, previous_accrued_fees_B, previous_accrued_fees_LP):
    accrued_fees_A = amm.fees_accrued_A
    accrued_fees_B = amm.fees_accrued_B
    accrued_fees_LP = amm.fees_accrued_LP
    if hasattr(amm, "rewards"):
        rewards_A = amm.rewards.get_amount_to_distribute(1)
    else:
        rewards_A = 0

    amm_token_A_value = amm.get_value_in_token_A()
    if amm_token_A_value == 0:
        return 0, accrued_fees_A, accrued_fees_B, accrued_fees_LP

    previous_total_fees_in_A = \
        amm.convert_to_A(previous_accrued_fees_A, previous_accrued_fees_B) + \
        amm.get_lp_value_in_token_A(previous_accrued_fees_LP)
    total_fees_in_A = amm.get_accrued_fees_in_token_A()
    gains_in_A = total_fees_in_A - previous_total_fees_in_A + rewards_A
    iteration_apr = TIME_UNITS_PER_YEAR * gains_in_A / amm_token_A_value
    """
    print(f"previous fees in A:     {previous_total_fees_in_A:,.2f}")
    print(f"total fees in A:        {total_fees_in_A:,.2f}")
    print(f"rewards in A:           {rewards_A:,.2f}")
    print(f"AMM value in A:         {amm_token_A_value:,.2f}")
    print(f"iteration apr:          {iteration_apr:.3%}")
    """
    return iteration_apr, accrued_fees_A, accrued_fees_B, accrued_fees_LP

def get_amm_average_apr(data, iteration):
    if iteration <= AMM_APR_PERIOD:
        return 0
    #print(data[iteration - AMM_APR_PERIOD : iteration]["amm_iteration_apr"])
    #print(f"average: {data[iteration - AMM_APR_PERIOD : iteration].mean()['amm_iteration_apr']:,.2f}")
    return data[iteration - AMM_APR_PERIOD : iteration].mean()["amm_iteration_apr"]

def get_chick_total_token_value(chicken, chick):
    token_amount = chicken.token.balance_of(chick.account)
    btkn_value = chicken.btkn.balance_of(chick.account) * chicken.btkn_amm.get_token_B_price()
    amm_value = chicken.btkn_amm.get_value_in_token_A_of(chick.account)

    return token_amount + chick.bond_amount + btkn_value + amm_value

