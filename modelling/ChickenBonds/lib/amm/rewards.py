class Rewards():
    def __init__(self, token, account, period):
        self.token = token
        self.account = account
        self.period = period
        assert period and period > 0
        self.distributed_amount = 0
        return

    def get_amount_to_distribute(self, elapsed_time):
        buffer_amount = self.token.balance_of(self.account) - self.distributed_amount
        """
        print(f"Balance:     {self.token.balance_of(self.account):,.2f}")
        print(f"Distributed: {self.distributed_amount:,.4f}")
        print(f"Buffer:      {buffer_amount:,.2f}")
        print(f"Amount:      {buffer_amount * elapsed_time / self.period:,.4f}")
        """
        assert buffer_amount >= 0
        if buffer_amount == 0:
            return 0
        if elapsed_time >= self.period:
            return buffer_amount

        # TODO: this is not exactly how it works
        return buffer_amount * elapsed_time / self.period

    def distribute_yield(self, elapsed_time):
        amount = self.get_amount_to_distribute(elapsed_time)

        self.distributed_amount = self.distributed_amount + amount

        return amount
