class User():
    def __init__(self, account):
        self.account = account
        self.bond_amount = 0
        self.bond_time = 0
        self.bond_target_profit = 0
        self.rebonder = False
        self.lp = False
        self.seller = False
        self.trader = False
        self.buy_price = 0

    def __str__(self):
        bond_string = ""
        if self.bond_amount > 0:
            bond_string = f"\n Bonded {self.bond_amount:,.2f} on day {self.bond_time}"
        return f"User with account \033[35m{self.account}\033[0m" + bond_string
