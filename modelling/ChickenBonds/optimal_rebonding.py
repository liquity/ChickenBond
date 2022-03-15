import sys, getopt
import math
from scipy.special import lambertw
import pandas as pd
import plotly.express as px

def get_args(argv):
    P = 0
    B = 0
    D = 0
    S = 0
    help_string = 'Usage: python3 coingecko_prices.py -P POL -B bonds -D DEX -S sTOKEN supply'
    if len(argv) == 0:
        print(help_string)
        sys.exit(2)
    try:
        opts, args = getopt.getopt(argv,"hP:B:D:S:",["pol=","bonds=","dex=","stoken_supply="])
    except getopt.GetoptError:
        print(help_string)
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print(help_string)
            sys.exit()
        elif opt in ("-P", "--pol"):
            P = float(arg)
        elif opt in ("-B", "--bonds"):
            B = float(arg)
        elif opt in ("-D", "--dex"):
            D = float(arg)
        elif opt in ("-S", "--stoken_supply"):
            S = float(arg)
    return P, B, D, S

def accrued(P, B, D, S, b):
    return b * S *  lambertw(P * math.exp(1) / (P + B + D)).real / P

def fair_price(P, B, D, S, b):
    return (P + B + D + accrued(P, B, D, S, b) * (P + B + D)/(S + accrued(P, B, D, S, b))) / (S + accrued(P, B, D, S, b))

def plot(P, B, D, S, domain, ):
    data = pd.DataFrame({})

    for i in range(domain[0], domain[1]):
        data = data.append(
            {
                "x": i,
                "y": fair_price(P, B, D, S, i),
                "var": "Fair Price"
            },
            ignore_index=True
        )

    fig = px.line(data, x="x", y="y", color="var", title=f"Fair price after rebonding")
    fig.update_xaxes(tick0=0, dtick=1, title_text="bond amount")
    fig.update_yaxes(title_text="Fair price")
    fig.show()

    return

def main(P, B, D, S):
    plot(P, B, D, S, [0, 25])

    return

if __name__ == '__main__':
    P, B, D, S = get_args(sys.argv[1:])
    main(P, B, D, S)
