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
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        """
        new_data = new_data.append(
            {
                "x": "Coop TOKEN",
                "stacked_x": f"{start_index + d:03}_T",
                "amount": data['coop_token'][start_index + d * group],
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "POL TOKEN",
                "stacked_x": f"{start_index + d:03}_T",
                "amount": data['pol_token'][start_index + d * group],
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
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
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
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
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "sTOKEN supply",
                "stacked_x": f"{start_index + d:03}_sTa",
                "amount": data['stoken_supply'][start_index + d * group],
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "sTOKEN value",
                "stacked_x": f"{start_index + d:03}_sTv",
                "amount": data['stoken_supply'][start_index + d * group] * data['stoken_price'][start_index + d * group],
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
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
        hover_data=['natural_rate', 'amm_apr', 'stoken_apr'],
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

def plot_stoken_price(data, max_value=200, description="", group=1, group_description="Day", show=True, save=False, get_prefixes=lambda:None):
    # TODO:
    # "x": start_index + d,
    start_index = data.index[0]

    fair_prices = []
    redemption_prices = []
    reserve_ratios = []
    rebond_times = []
    chicken_in_times = []
    for d in range(len(data.index) // group):
        # Reserve ratio without AMM
        fair_price = min(
            data['fair_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        fair_prices.append(fair_price)

        """
        # TWAP
        twap_price = data['stoken_twap'][start_index + d * group]
        twap_price = min(
            twap_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        """

        # Spot
        """
        spot_price = data['stoken_price'][start_index + d * group]
        spot_price = min(
            spot_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        """

        # Redemption price
        redemption_price = min(
            data['redemption_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        redemption_prices.append(redemption_price)

        # Reserve ratio
        reserve_ratio = min(
            data['reserve_ratio_no_amm'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        reserve_ratios.append(reserve_ratio)

        # Rebond time
        rebond_times.append(data['rebond_time'][start_index + d * group])

        # Chicken in time for optimal APR
        chicken_in_times.append(data['chicken_in_time'][start_index + d * group])

    #fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - sTOKEN Price")
    fig = make_subplots(specs=[[{"secondary_y": True}]], subplot_titles=[f"{description} - sTOKEN Price"])

    fig.add_trace(
        go.Scatter(y=fair_prices, name="Fair Price"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(y=redemption_prices, name="Redemption Price"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(y=reserve_ratios, name="Reserve Ratio"),
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

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="sTOKEN Price in TOKEN", secondary_y=False)
    fig.update_yaxes(title_text="Rebond time", secondary_y=True)

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "sTOKEN_price")
    return

def plot_aprs(data, max_value=20, description="", group=1, group_description="Day", show=True, save=False, get_prefixes=lambda:None
):

    #print(data['edebt_price'])
    start_index = data.index[0]

    new_data = pd.DataFrame({
        "x": [],
        "price": [],
    })
    for d in range(len(data.index) // group):
        new_data = new_data.append(
            {
                "x": d,
                "y": data['natural_rate'][start_index + d * group] * 100,
                "var": "Natural Rate"
            },
            ignore_index=True
        )
        """
        new_data = new_data.append(
            {
                "x": d,
                "y": data['amm_average_apr'][start_index + d * group] * 100,
                "var": "AMM"
            },
            ignore_index=True
        )
        """

        stoken_spot = data['stoken_apr'][start_index + d * group] * 100
        stoken_spot = min(
            stoken_spot,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": d,
                "y": stoken_spot,
                "var": "Stoken (spot)"
            },
            ignore_index=True
        )

        stoken_twap = data['stoken_apr_twap'][start_index + d * group] * 100
        stoken_twap = min(
            stoken_twap,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": d,
                "y": stoken_twap,
                "var": "Stoken (TWAP)"
            },
            ignore_index=True
        )

    fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - APRs")

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="APR %")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "APRs")
    return

def plot_chicks(data, chicken, chicks, description="", show=True, save=False, get_prefixes=lambda:None):
    stoken_price = data["stoken_price"][len(data)-1]
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
            chick_name = chick.account.replace('chick', 'rebnd')
        if chick.lp:
            chick_name = chick.account.replace('chick', 'liqpr')

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
                "x": "sTOKEN",
                "stacked_x": chick_name,
                "amount": chicken.stoken.balance_of(chick.account) * stoken_price,
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "TOKEN/sTOKEN LP tokens",
                "stacked_x": chick_name,
                "amount": chicken.stoken_amm.get_value_in_token_A_of(chick.account),
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
        price_max_value, apr_max_value,
        description="",
        group=30,
        group_description="Month",
        show=True,
        save=False,
        global_prefix='001',
        tester_prefixes_getter=lambda:None
):
    plot_chicken_state(data, description, group, group_description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '1'))
    plot_stoken_price(data, price_max_value, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '2'))
    plot_aprs(data, apr_max_value, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '3'))
    plot_chicks(data, chicken, chicks, description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '6'))
    return
