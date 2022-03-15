import math
import pandas as pd
import plotly.express as px

ITERATIONS = 20

def plot_var(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S, result_index, title, y_desc):
    result = calculate_fair_price(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S, ITERATIONS)
    #return
    df = pd.DataFrame({})
    for j in range(ITERATIONS):
        df = df.append(
            {
                "t": result["time"][j],
                "y": result["fair_price"][j],
                "var": "Fair price"
            },
            ignore_index=True
        )
        df = df.append(
            {
                "t": result["time"][j],
                "y": result["redemption_price"][j],
                "var": "Redepmtion price"
            },
            ignore_index=True
        )
        df = df.append(
            {
                "t": result["time"][j],
                "y": 1 + result["time"][j] * r_m / 365,
                "var": "Natural rate"
            },
            ignore_index=True
        )
        df = df.append(
            {
                "t": result["time"][j],
                "y": (1 +  r_m / 365) ** result["time"][j],
                "var": "Natural rate (exp)"
            },
            ignore_index=True
        )

    #print(df)
    fig = px.line(df, x="t", y="y", color="var", title=title, markers=True)
    fig.update_xaxes(title_text="Time")
    fig.update_yaxes(title_text=y_desc)
    fig.show()

    return

def plot_fair_price(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S):
    plot_var(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S, "fair_price", "Fair price as a function of initial pending amount", "Price (p_f)")
    return

def log_header():
    print(f"Acquired \tPending \tPermanent \tTotal    \tbTKN supply \tBack ratio \tFair price \tOp Time")
    return
def log_iteration(q_p, q_a, q_d, S, p_r, p_f, T_OP):
    print(f"{q_a:8,.2f} \t{q_p:8,.2f} \t{q_d:8,.2f} \t{q_p+q_a+q_d:8,.2f} \t{S:8,.2f} \t{p_r:8,.2f} \t{p_f:8,.2f} \t{T_OP:8,.2f}")
    return
def calculate_prices_and_time(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S):
    p_r = q_a / S
    #print(f"p_r: {p_r}")
    #p_f = 1 + ((q_a + q_p) * r_s + q_d * d_d * r_d) / S
    #alpha = 1
    #alpha = 1 + 0.3/q_p
    alpha = q_a / (q_p + q_d)
    #print(f"alpha: {alpha:,.2f}")
    p_f = (q_a + alpha * q_p + q_d * d_d * r_d/r_s) / S
    #p_f = 1.5 * p_r
    """
    print(f"num: {q_a + alpha * q_p + q_d * d_d * r_d/r_s:,.2f}")
    print(f"num: {q_a:,.2f}")
    print(f"num: {alpha * q_p:,.2f}")
    print(f"num: {q_d * d_d * r_d/r_s:,.2f}")
    print(f"den: {S:,.2f}")
    print(f"p_f: {p_f:,.2f}")
    """
    T_OP = (p_r + math.sqrt(p_f * p_r)) / (p_f - p_r)
    return p_r, p_f, T_OP

def calculate_fair_price(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S, iterations):
    p_r, p_f, T_OP = calculate_prices_and_time(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S)

    redemption_price = [p_r]
    fair_price = [p_f]
    time = [0]
    pending = [q_p]
    acquired = [q_a]
    dex = [q_d]
    log_header()
    log_iteration(q_p, q_a, q_d, S, p_r, p_f, T_OP)
    accumulated_time = 0
    for i in range(1, iterations):
        T_factor = T_OP / (T_OP + 1)
        q_a = q_a + ((q_a + q_p) * r_s  + q_d * r_d) * T_OP / 365 + q_p * T_factor
        q_d = q_d + q_p * (1 - T_factor)
        S = S + q_p / p_r * T_factor
        q_p = q_p * p_f / p_r * T_factor

        p_r, p_f, T_OP = calculate_prices_and_time(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S)

        redemption_price.append(p_r)
        fair_price.append(p_f)
        accumulated_time = accumulated_time + T_OP
        time.append(accumulated_time)
        pending.append(q_p)
        acquired.append(q_a)
        dex.append(q_d)

        log_iteration(q_p, q_a, q_d, S, p_r, p_f, T_OP)

    return {
        "redemption_price": redemption_price,
        "fair_price": fair_price,
        "time": time,
        "pending": pending,
        "acquired": acquired,
        "dex": dex
    }

def main():
    #q_p = 1
    #calculate_fair_price(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S, ITERATIONS)

    #"""
    r_m = 0.1
    r_s = 0.1
    r_d = 0.05
    d_d = 0.96
    q_p = 1
    q_a = 1
    q_d = 1
    S = 1
    """
    r_m = 0.1
    r_s = 0.1
    r_d = 0.1
    d_d = 1
    q_p = 500
    q_a = 1000
    q_d = 500
    S = 1000
    """

    plot_fair_price(r_m, r_s, r_d, d_d, q_p, q_a, q_d, S)

    return

if __name__ == "__main__":
    main()
