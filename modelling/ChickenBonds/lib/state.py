import pandas as pd

def init_data():
    return pd.DataFrame()

def state_to_row(
        chicken,
        tester,
        natural_rate,
        data,
        iteration
):
    return {
        "amm_token": chicken.amm.token_A_balance(),
        "amm_stoken": chicken.amm.token_B_balance(),
        "coop_token": chicken.coop_token_balance(),
        "pol_token": chicken.pol_token_balance(),
        #"total_coll": ,
        #"outstanding_debt": chicken.outstanding_debt,
        "stoken_supply": chicken.stoken.total_supply,
        #"borrowed": borrowed_amount,
        #"repaid": repaid_amount,
        "natural_rate": natural_rate,
        "amm_iteration_apr": chicken.amm_iteration_apr,
        "amm_average_apr": chicken.amm_average_apr,
        "stoken_apr": tester.get_stoken_apr_spot(chicken),
        "stoken_apr_twap": tester.get_stoken_apr_twap(chicken, data, iteration),
        "stoken_price": tester.get_stoken_spot_price(chicken),
        "stoken_twap": tester.get_stoken_twap(data, iteration),
        "pol_ratio_with_amm": tester.get_pol_ratio_with_amm(chicken),
        "pol_ratio_no_amm": tester.get_pol_ratio_no_amm(chicken),
        "redemption_price": tester.get_pol_ratio(chicken),
        "reserve_ratio_with_amm": tester.get_reserve_ratio_with_amm(chicken),
        "reserve_ratio_no_amm": tester.get_reserve_ratio_no_amm(chicken),
        "fair_price": tester.get_fair_price(chicken),
    }
