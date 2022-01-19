import pandas as pd
import plotly.express as px

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
                "x": "AMM sTOKEN",
                "stacked_x": f"{start_index + d:03}_amm",
                "amount": data['amm_stoken'][start_index + d * group],
                "stoken_apr": f"{data['stoken_apr'][start_index + d * group]:.3%}",
                "amm_apr": f"{data['amm_average_apr'][start_index + d * group]:.3%}",
                "natural_rate": f"{data['natural_rate'][start_index + d * group]:.3%}",
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "AMM sTOKEN (TOKEN value)",
                "stacked_x": f"{start_index + d:03}_amm",
                "amount": data['amm_stoken'][start_index + d * group] * data['stoken_price'][start_index + d * group] - data['amm_stoken'][start_index + d * group],
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
    colors = ['#274C77', '#00D995', '#b6134a', '#F3DE8A', '#FBF5DB', '#5DB7DE', '#9dd3eb']
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
    #print(data['stoken_price'])
    start_index = data.index[0]

    new_data = pd.DataFrame({
        "x": [],
        "price": [],
    })
    for d in range(len(data.index) // group):
        # Reserve ratio without AMM
        fair_price = min(
            data['fair_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": start_index + d,
                "y": fair_price,
                "var": "Fair Price"
            },
            ignore_index=True
        )

        # TWAP
        twap_price = data['stoken_twap'][start_index + d * group]
        twap_price = min(
            twap_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": start_index + d,
                "y": twap_price,
                "var": "TWAP"
            },
            ignore_index=True
        )

        # Spot
        spot_price = data['stoken_price'][start_index + d * group]
        spot_price = min(
            spot_price,
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": start_index + d,
                "y": spot_price,
                "var": "Spot"
            },
            ignore_index=True
        )

        # Redemption price
        redemption_price = min(
            data['redemption_price'][start_index + d * group],
            max_value # to avoid “zooming out too much with the initial spike”
        )
        new_data = new_data.append(
            {
                "x": start_index + d,
                "y": redemption_price,
                "var": "Redemption Price"
            },
            ignore_index=True
        )

    fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - sTOKEN Price")

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="sTOKEN Price in TOKEN")

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
        new_data = new_data.append(
            {
                "x": d,
                "y": data['amm_average_apr'][start_index + d * group] * 100,
                "var": "AMM"
            },
            ignore_index=True
        )

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


def plot_borrow_repay(data, description="", group=7, group_description="Week", show=True, save=False, get_prefixes=lambda:None):
    start_index = data.index[0]

    new_data = pd.DataFrame({
        "x": [],
        "amount": [],
    })
    for d in range(1, len(data.index) // group + 1):
        new_data = new_data.append(
            {
                "x": d,
                "y": data['borrowed'][start_index + (d-1) * group : start_index + d * group].sum(),
                "var": "Borrowed"
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": d,
                "y": data['repaid'][start_index + (d-1) * group : start_index + d * group].sum(),
                "var": "Repaid"
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": d,
                "y": data['outstanding_debt'][start_index + d * group - 1],
                "var": "Outstanding debt"
            },
            ignore_index=True
        )

    fig = px.line(new_data, x="x", y="y", color="var", title=f"{description} - Borrowing / Repayment")

    fig.update_xaxes(tick0=0, dtick=len(data.index)//group/20, title_text=group_description)
    fig.update_yaxes(title_text="Amount")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "borrowing_repayment")
    return

def plot_chicks(data, chicken, chicks, description="", show=True, save=False, get_prefixes=lambda:None):
    stoken_price = data["stoken_price"][len(data)-1]
    new_data = pd.DataFrame({
        "x": [],
        "stacked_x": [],
        "amount": [],
    })
    for chick in chicks:
        new_data = new_data.append(
            {
                "x": "COLL",
                "stacked_x": chick.account,
                "amount": chicken.coll_token.balance_of(chick.account),
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "TOKEN",
                "stacked_x": chick.account,
                "amount": chicken.token.balance_of(chick.account),
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "Bonded TOKEN",
                "stacked_x": chick.account,
                "amount": chick.bond_amount,
            },
            ignore_index=True
        )
        new_data = new_data.append(
            {
                "x": "sTOKEN",
                "stacked_x": chick.account,
                "amount": chicken.stoken.balance_of(chick.account) * stoken_price,
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

def plot_chicks_total_value(chicken, chicks, description="", show=True, save=False, get_prefixes=lambda:None):
    new_data = pd.DataFrame({
        "x": [],
        "amount": [],
    })
    for chick in chicks:
        new_data = new_data.append(
            {
                "x": chick.account,
                "amount": chicken.user_total_assets_value(chick),
            },
            ignore_index=True
        )

    #print(new_data)

    fig = px.bar(
        new_data,
        x='x',
        y='amount',
        labels={'x': 'Balance', 'x': 'Chick'},
    )

    fig.update_layout(title_text=f"{description} - Chick total assets value in TOKEN")

    if show: fig.show()
    maybe_save(fig, save, get_prefixes, "Chick_total_assets")

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
    #plot_borrow_repay(data, description, show=show, save=save, get_prefixes=get_prefixes_getter(global_prefix, tester_prefixes_getter, '5'))
    plot_chicks(data, chicken, chicks, description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '6'))
    #plot_chicks_total_value(chicken, chicks, description, show, save, get_prefixes_getter(global_prefix, tester_prefixes_getter, '7'))
    return
