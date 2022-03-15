import pandas as pd
import plotly.express as px

r_m = 0.1
r_d = 0.05
d_d = 0.4
q_a = 1
q_d = 2
S = 1
ITERATIONS = 20

def plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, result_index, title, y_desc):
    df = pd.DataFrame({})
    for i in range(100):
        q_p = i / 10
        result = calculate_fair_price(r_m, r_d, d_d, q_p, q_a, q_d, S, ITERATIONS)

        for j in range(ITERATIONS):
            df = df.append(
                {
                    "x": q_p,
                    "y": result[result_index][j],
                    "iteration": f"{int(j)}"
                },
                ignore_index=True
            )

    fig = px.line(df, x="x", y="y", color="iteration", title=title)
    fig.update_xaxes(title_text="Amount (q_p)")
    fig.update_yaxes(title_text=y_desc)
    fig.show()

    return

def plot_fair_price_q_p(r_m, r_d, d_d, q_a, q_d, S):
    plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, 0, "Fair price as a function of initial pending amount", "Price (p_f)")
    return

def plot_redemption_price_q_p(r_m, r_d, d_d, q_a, q_d, S):
    plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, 1, "Redemption price as a function of initial pending amount", "Price (p_r)")
    return

def plot_pending_q_p(r_m, r_d, d_d, q_a, q_d, S):
    plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, 2, "Pending amount as a function of initial pending amount", "Pending (q_p)")
    return

def plot_acquired_q_p(r_m, r_d, d_d, q_a, q_d, S):
    plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, 3, "Acquired amount as a function of initial pending amount", "Acquired (q_a)")
    return

def plot_dex_q_p(r_m, r_d, d_d, q_a, q_d, S):
    plot_var_q_p(r_m, r_d, d_d, q_a, q_d, S, 4, "DEX amount as a function of initial pending amount", "DEX (q_d)")
    return

def build_values(q_p, q_a, q_d, S, p_r, p_f):
    return {
        "q_p": q_p,
        "q_a": q_a,
        "q_d": q_d,
        "S": S,
        "p_r": p_r,
        "p_f": p_f,
    }

def calculate_fair_price(r_m, r_d, d_d, q_p, q_a, q_d, S, iterations):
    D = r_d / r_m * d_d

    p_r = q_a / S
    p_f = (q_a + q_p + q_d * D) / S

    fair_price = [p_f]
    redemption_price = [p_r]
    pending = [q_p]
    acquired = [q_a]
    dex = [q_d]
    for i in range(1, iterations):
        v = build_values(q_p, q_a, q_d, S, p_r, p_f)
        #q_b = v["q_p"] * v["q_d"] / v["q_a"] * v["q_a"] / (v["q_a"] + v["q_d"]) * v["p_f"] / v["p_r"]
        q_b = v["q_p"] * v["q_d"] / (v["q_a"] + v["q_d"]) * v["p_f"] / v["p_r"]
        q_p = q_b + v["q_p"] * (1 - v["q_d"] / v["q_a"])
        if i == 10:
            print(f"q_p: {q_p:,.2f}")
        step_factor = 1 + v["q_d"] / v["q_a"] * v["q_p"] / (v["q_a"] + v["q_d"])
        q_a = v["q_a"] * step_factor
        q_d = v["q_d"] * step_factor
        S = v["S"] * step_factor
        p_r = v["q_a"] / v["S"]

        p_f = v["q_p"] * (1 + v["q_d"]/(v["q_a"] + v["q_d"]) * v["p_f"] / v["p_r"] - v["q_d"] / v["q_a"]) / v["S"] / step_factor + (v["q_a"] + v["q_d"] * D) / v["S"]
        #print(f"p_f: {p_f:,.2f}")

        fair_price.append(p_f)
        redemption_price.append(p_r)
        pending.append(q_p)
        acquired.append(q_a)
        dex.append(q_d)

    return [fair_price, redemption_price, pending, acquired, dex]

if __name__ == "__main__":
    #q_p = 1
    #calculate_fair_price(r_m, r_d, d_d, q_p, q_a, q_d, S, ITERATIONS)

    plot_fair_price_q_p(r_m, r_d, d_d, q_a, q_d, S)
    #plot_redemption_price_q_p(r_m, r_d, d_d, q_a, q_d, S)
    #plot_pending_q_p(r_m, r_d, d_d, q_a, q_d, S)
    #plot_acquired_q_p(r_m, r_d, d_d, q_a, q_d, S)
    #plot_dex_q_p(r_m, r_d, d_d, q_a, q_d, S)
