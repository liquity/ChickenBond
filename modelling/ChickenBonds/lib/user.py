class User():
    def __init__(self, account):
        self.account = account
        self.bond_amount = 0
        self.bond_time = 0
        self.bond_target_profit = 0
        self.rebonder = False

    def __str__(self):
        bond_string = ""
        if self.bond_amount > 0:
            bond_string = f"\n Bonded {self.bond_amount:,.2f} on day {self.bond_time}"
        return f"User with account {self.account}" + bond_string
