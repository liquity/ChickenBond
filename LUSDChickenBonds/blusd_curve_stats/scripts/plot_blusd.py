from datetime import datetime
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

df = pd.read_csv('./data/curve_repegs.csv')
#print(df.head())

fig = make_subplots(
    specs=[[{"secondary_y": True}]],
    subplot_titles=[f"bLUSD AMM Pool"]
)

fig.add_trace(
    go.Scatter(
        x=df['date'],
        y=df['price_lusd3crv']/df['price_scale'],
        name="Price scale"
    ),
    secondary_y=False,
)
fig.add_trace(
    go.Scatter(
        x=df['date'],
        y=df['price_lusd3crv']/df['price_oracle'],
        name="Price oracle"
    ),
    secondary_y=False,
)
fig.add_trace(
    go.Scatter(
        x=df['date'],
        y=df['price_lusd3crv']/df['price_effective'],
        name="Trades",
        mode='markers'
    ),
    secondary_y=False,
)
fig.add_trace(
    go.Scatter(
        x=df['date'],
        y=1/df['price_scale'],
        name="Price scale (in LUSD3CRV)"
    ),
    secondary_y=False,
)
fig.add_trace(
    go.Bar(
        x=df['date'],
        y=df['volume'],
        name="Volume",
        width=1000000
    ),
    secondary_y=True,
)

fig.update_yaxes(title_text="bLUSD Price (in LUSD)", secondary_y=False)
fig.update_yaxes(title_text="Volume", secondary_y=True)

fig.show()
