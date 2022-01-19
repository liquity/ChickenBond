from lib.constants import *

def get_amm_iteration_apr(chicken, previous_accrued_fees_A, previous_accrued_fees_B):
    accrued_fees_A = chicken.amm.fees_accrued_A
    accrued_fees_B = chicken.amm.fees_accrued_B

    amm_token_A_value = chicken.amm.get_value_in_token_A()
    if amm_token_A_value == 0:
        return 0, accrued_fees_A, accrued_fees_B

    previous_total_fees_in_A = chicken.amm.convert_to_A(previous_accrued_fees_A, previous_accrued_fees_B)
    total_fees_in_A = chicken.amm.get_accrued_fees_in_token_A()
    #print(f"previous fees in A: {previous_total_fees_in_A:,.2f}")
    #print(f"total fees in A:    {total_fees_in_A:,.2f}")
    return \
        TIME_UNITS_PER_YEAR * (total_fees_in_A - previous_total_fees_in_A) / amm_token_A_value, \
        accrued_fees_A, \
        accrued_fees_B

def get_amm_average_apr(data, iteration):
    if iteration <= AMM_APR_PERIOD:
        return 0
    #print(data[iteration - AMM_APR_PERIOD : iteration]["amm_iteration_apr"])
    #print(f"average: {data[iteration - AMM_APR_PERIOD : iteration].mean()['amm_iteration_apr']:,.2f}")
    return data[iteration - AMM_APR_PERIOD : iteration].mean()["amm_iteration_apr"]
