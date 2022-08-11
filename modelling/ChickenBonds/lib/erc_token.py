class Token():
    def __init__(self, symbol):
        self.symbol = symbol
        self.total_supply = 0.0
        self.balances = {}

    def __str__(self):
        return f"Token {self.symbol}. Total supply: {self.total_supply}"

    def mint(self, account, amount):
        #print(f"amount: {amount:,.2f}")
        #print(f"bal:    {self.balances.get(account, 0.0):,.2f}")
        #print(f"total:  {self.total_supply:,.2f}")
        self.total_supply = self.total_supply + amount
        self.balances[account] = self.balances.get(account, 0.0) + amount
        #print(f"bal:    {self.balances[account]:,.2f}")
        #print(f"total:  {self.total_supply:,.2f}")
        #assert self.total_supply >= self.balances[account]

    def burn(self, account, amount):
        try:
            self.total_supply = self.total_supply - amount
            self.balances[account] = self.balances.get(account, 0.0) - amount
            assert self.total_supply >= 0.0
            assert self.balances[account] >= 0.0
            # TODO: rounding issues
            #print(f"bal:    {self.balances[account]:,.2f}")
            #assert self.total_supply >= self.balances[account]
        except:
            print(f"{self.symbol} token burn from {account}")
            print(f"amount: {amount:,}")
            print(f"supply: {self.total_supply:,}")
            print(f"bal:    {self.balances[account]:,}")
            raise RuntimeError('Negative balance!')

    def transfer(self, sender, recipient, amount):
        try:
            self.balances[recipient] = self.balances.get(recipient, 0.0) + amount
            self.balances[sender] = self.balances.get(sender, 0.0) - amount
            # Balance of pools can turn into tiny negative value thanks to floating point arithmetic
            # if everyone withdraws from the pool and the withdrawable amounts are calculated using
            # multiplication / division (e.g. if it involves redistribution).
            assert self.balances[sender] >= -1e-9
        except:
            print(f"{self.symbol} token transfer from {sender} to {recipient}")
            print(f"amount: {amount:,}")
            print(f"bal b4: {self.balances[sender] + amount:,}")
            print(f"bal:    {self.balances[sender]:,}")
            raise RuntimeError('Negative balance!')

    def balance_of(self, account):
        return self.balances.get(account, 0.0)
