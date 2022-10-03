import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

from lib.constants import *
from lib.chicken import *

def maybe_save(fig, save, get_prefixes, plot_name):
    if save:
        global_prefix, tester_prefix, plot_prefix, file_tester_description = get_prefixes()
        fig.write_image(
            f"images/{global_prefix}_{tester_prefix}_{plot_prefix}_{file_tester_description}_{plot_name}.png",
            width=1920,
            height=1080
        )
    return

def plot_chicken_state(data, description="", group=7, group_description="Week", show=True, save=False, get_prefixes=lambda:None):
    start_index = data.index[0]

    new_data = pd.DataFrame({
        "x": [],
        "stacked_x": [],
        "amount": [],
    })
    for d in range(len(data.index) // group):
        """
        new_data = new_data.append(
            {
                "x": "Outstanding Debt",
                "stacked_x": f"{start_index + d:03}_O",
                "amount": data['outstanding_debt'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        """
        new_data = new_data.append(
            {
                "x": "Pending TOKEN",
                "stacked_x": f"{start_index + d:03}_T",
                "amount": data['pending_token'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "Reserve TOKEN",
                "stacked_x": f"{start_index + d:03}_T",
                "amount": data['reserve_token'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "AMM TOKEN",
                "stacked_x": f"{start_index + d:03}_amm",
                "amount": data['amm_token'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "AMM ETH",
                "stacked_x": f"{start_index + d:03}_amm",
                "amount": data['amm_coll'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "bTKN supply",
                "stacked_x": f"{start_index + d:03}_sTa",
                "amount": data['btkn_supply'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "bTKN value",
                "stacked_x": f"{start_index + d:03}_sTv",
                "amount": data['btkn_supply'][start_index + d * group] * data['btkn_price'][start_index + d * group],
                "btkn_apr": f"{data['btkn_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )

    #print(new_data)

    #colors = px.colors.qualitative.Plotly
    # debt: '#BA2D0B'
    # coll value: #BF5DB
    colors = ['#274C77', '#00D995', '#b6134a', '#F3DE8A', '#5DB7DE', '#9dd3eb']
    fig = px.bar(
        new_data,
        x='stacked_x',
        y='amount',
        #range_y=[0, MAX_Y_RANGE],
        color='x',
        color_discrete_sequence=colors,
        labels={'x': 'Variable', 'stacked_x': 'Time'},
        hover_data=['natural_rate', 'amm_apr', 'btkn_apr'],
    )

    # Change the bar mode
    fig.update_layout(
        barmode='stack',
        title_text=f"{description} - Chicken Bonds state",
        xaxis={'categoryorder':'category ascending'}
    )
    fig.update_xaxes(tick0=0, dtick=1, title_text=group_description)

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "Chicken_bonds_state")

    return

def plot_btkn_price(data, max_value=200, max_time_value=150, description="", group=1, group_description="Day", show=True, save=False, get_prefixes=lambda:None):
    # TODO:
    # "x": start_index + d,
    start_index = data.index[0]

    fair_prices = []
    redemption_prices = []
    spot_prices = []
    rebond_times = []
    chicken_in_times = []
    avg_age = []
    for d in range(len(data.index) // group):
        # Fair price
        fair_price = min(
            data['fair_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        fair_prices.append(fair_price)

        """
        # TWAP
        twap_price = data['btkn_twap'][start_index + d * group]
        twap_price = min(
            twap_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        """

        # Spot
        spot_price = data['btkn_price'][start_index + d * group]
        spot_price = min(
            spot_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        spot_prices.append(spot_price)

        # Redemption price
        redemption_price = min(
            data['redemption_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        redemption_prices.append(redemption_price)

        # Rebond time
        rebond_time = min(
            data['rebond_time'][start_index + d * group],
            max_time_value
        )
        rebond_times.append(rebond_time)

        # Chicken in time for optimal APR
        chicken_in_time = min(
            data['chicken_in_time'][start_index + d * group],
            max_time_value
        )
        chicken_in_times.append(chicken_in_time)

        # Average outstading bond age
        avg_age.append(data['avg_age'][start_index + d * group])

    #fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - bTKN Price")
    fig = make_subplots(specs=[[{"secondary_y": True}]], subplot_titles=[f"{description} - bTKN Price"])

    fig.add_trace(
        go.Scatter(y=fair_prices, name="Fair Price"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(y=redemption_prices, name="Redemption Price"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(y=spot_prices, name="Market Price"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(y=rebond_times, name="Rebond Time"),
        secondary_y=True,
    )

    fig.add_trace(
        go.Scatter(y=chicken_in_times, name="Chicken in Time"),
        secondary_y=True,
    )

    fig.add_trace(
        go.Scatter(y=avg_age, name="Avg. Outstanding Bond Age"),
        secondary_y=True,
    )

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="bTKN Price in TOKEN", secondary_y=False)
    fig.update_yaxes(title_text="Rebond time", secondary_y=True)

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "bTKN_price")
    return

def append_apr_data(start_index, group, d, data, new_data, min_value, max_value, variable, description):
    new_value = data[variable][start_index + d * group] * 100
    new_value = max(
        min(
            new_value,
            max_value # to avoid “zooming out too much with the initial spike”
        ),
        min_value
    )
    new_data = new_data.append(
        {
            "x": d,
            "y": new_value,
            "var": description
        },
        ignore_index=True
    )

    return new_data

def plot_aprs(data, min_value=-10, max_value=20, description="", group=1, group_description="Day", show=True, save=False, get_prefixes=lambda:None
):

    #print(data['edebt_price'])
    start_index = data.index[0]

    new_data = pd.DataFrame({})
    for d in range(len(data.index) // group):
        new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "natural_rate", "Natural Rate")
        #new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "btkn_apr", "bTKN (spot)")
        #new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "amm_iteration_apr", "bTKN AMM (spot)")
        new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "bonding_apr_twap", "Bonding (avg)")
        new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "btkn_apr_twap", "bTKN (avg)")
        new_data = append_apr_data(start_index, group, d, data, new_data, min_value, max_value, "amm_average_apr", "bTKN AMM (avg)")


    fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - APRs")

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="APR %")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "APRs")
    return

def plot_slippage(data, description="", group=1, group_description="Day", show=True, save=False, get_prefixes=lambda:None
):
    #print(data['edebt_price'])
    start_index = data.index[0]

    new_data = pd.DataFrame({})
    for d in range(len(data.index) // group):
        new_data = new_data.append(
            {
                "x": d,
                "y": data["sell_slippage"][start_index + d * group] * 100,
                "var": "Sell bTKN"
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": d,
                "y": data["buy_slippage"][start_index + d * group] * 100,
                "var": "Buy bTKN"
            },
            ignore_index=True
        )


    fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - Slippage")

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="Slippage %")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "slippage")
    return

def plot_chicks(data, chicken, chicks, description="", show=True, save=False, get_prefixes=lambda:None):
    btkn_price = data["btkn_price"][len(data)-1]
    new_data = pd.DataFrame({
        "x": [],
        "stacked_x": [],
        "amount": [],
    })

    # sort chicks array for plotting
    chicks.sort(key = lambda c: c.account)

    for chick in chicks:
        chick_name = chick.account
        if chick.rebonder:
            chick_name = chick.account.replace('chick', 'rebond')
        if chick.lp:
            chick_name = chick.account.replace('chick', 'liq_pr')
        if chick.seller:
            chick_name = chick.account.replace('chick', 'seller')
        if chick.trader:
            chick_name = chick.account.replace('chick', 'trader')

        new_data = new_data.append(
            {
                "x": "COLL",
                "stacked_x": chick_name,
                "amount": chicken.coll_token.balance_of(chick.account),
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "TOKEN",
                "stacked_x": chick_name,
                "amount": chicken.token.balance_of(chick.account),
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "Bonded TOKEN",
                "stacked_x": chick_name,
                "amount": chick.bond_amount,
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "bTKN",
                "stacked_x": chick_name,
                "amount": chicken.btkn.balance_of(chick.account) * btkn_price,
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "TOKEN/bTKN LP tokens",
                "stacked_x": chick_name,
                "amount": chicken.btkn_amm.get_value_in_token_A_of(chick.account),
            },
            ignore_index=True
        )

    #print(new_data)

    colors = ['#CBB9A8', '#274C77', '#5DB7DE', '#00D995', '#F3DE8A']
    fig = px.bar(
        new_data,
        x='stacked_x',
        y='amount',
        #range_y=[0, MAX_Y_RANGE],
        color='x',
        color_discrete_sequence=colors,
        labels={'x': 'Balance', 'stacked_x': 'Chick'},
    )

    # Change the bar mode
    fig.update_layout(barmode='stack', title_text=f"{description} - Chick balances")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "Chick_balances")

    return

def get_prefixes_getter(global_prefix, tester_prefixes_getter, plot_prefix):
    tester_prefix = ''
    file_tester_description = ''
    if tester_prefixes_getter():
        tester_prefix, file_tester_description = tester_prefixes_getter()
    return lambda : (global_prefix, tester_prefix, plot_prefix, file_tester_description)

def plot_charts(
        chicken,
        chicks,
        data,
        price_max_value, time_max_value, apr_min_value, apr_max_value,
        description="",
        group=30,
        group_description="Month",
        show=True,
        save=False,
        global_prefix='001',
        tester_prefixes_getter=lambda:None
):
    if not show and not save:
        return
    plot_chicken_state(data, description, group, group_description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '1'))
    plot_btkn_price(data, price_max_value, time_max_value, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '2'))
    plot_aprs(data, apr_min_value, apr_max_value, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '3'))
    plot_slippage(data, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '3'))
    plot_chicks(data, chicken, chicks, description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '6'))
    return
