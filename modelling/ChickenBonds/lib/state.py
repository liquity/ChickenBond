import pandas as pd

def init_data():
    return pd.DataFrame()

def state_to_row(
        chicken,
        tester,
        natural_rate,
        avg_age,
        data,
        iteration
):
    sell_slippage, buy_slippage = tester.get_btkn_amm_slippage(chicken, debug=False)

    return {
        "amm_token": chicken.amm.token_A_balance(),
        "amm_coll": chicken.amm.token_B_balance(),
        "pending_token": chicken.pending_token_balance(),
        "reserve_token": chicken.reserve_token_balance(),
        #"total_coll": ,
        #"outstanding_debt": chicken.outstanding_debt,
        "btkn_supply": chicken.btkn.total_supply,
        #"borrowed": borrowed_amount,
        #"repaid": repaid_amount,
        "natural_rate": natural_rate,
        "avg_age": avg_age,
        "amm_iteration_apr": chicken.amm_iteration_apr,
        "amm_average_apr": chicken.amm_average_apr,
        "btkn_apr": tester.get_btkn_apr_spot(chicken, data, iteration),
        "btkn_apr_twap": tester.get_btkn_apr_twap(chicken, data, iteration),
        "bonding_apr": tester.get_bonding_apr_spot(chicken),
        "bonding_apr_twap": tester.get_bonding_apr_twap(chicken, data, iteration),
        "btkn_price": tester.get_btkn_spot_price(chicken),
        "btkn_twap": tester.get_btkn_twap(data, iteration),
        "backing_ratio": chicken.get_backing_ratio(),
        "redemption_price": tester.get_backing_ratio(chicken),
        "fair_price": tester.get_fair_price(chicken),
        "rebond_time": tester.get_rebond_time(chicken),
        "chicken_in_time": tester.get_optimal_apr_chicken_in_time(chicken),
        "sell_slippage": sell_slippage,
        "buy_slippage": buy_slippage,
    }
