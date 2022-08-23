import math

from lib.amm.amm_base import *

class AmmMockPrice(AmmBase):
    def __init__(self, pool_account, token_A, token_B, fee):
        self.pool_account = pool_account # mimics the address
        self.token_A = token_A
        self.token_B = token_B
        self.lp_token = Token(token_A.symbol + token_B.symbol)
        assert fee > 0.0 and fee < 1.0
        self.fee = fee
        self.fees_accrued_A = 0.0
        self.fees_accrued_B = 0.0
        self.A_price = 1.0

    def __str__(self):
        return f"\n - {self.token_A.symbol} amount: {self.token_A.balance_of(self.pool_account):,.2f}" + \
            f"\n - {self.token_B.symbol} amount: {self.token_B.balance_of(self.pool_account):,.2f}" + \
            f"\n - Price {self.token_A.symbol}/{self.token_B.symbol}: {self.get_token_A_price():,.2f}" + \
            f"\n - \033[36mPrice {self.token_B.symbol}/{self.token_A.symbol}: {self.get_token_B_price():,.2f}\033[0m" + \
            f"\n - LP tokens total supply {self.get_total_liquidity():,.2f}"

    # to be discounted for APR calculation
    def set_initial_A_liquidity(self, initial_A_liquidity):
        self.initial_A_liquidity = initial_A_liquidity
        return

    def set_price_A(self, price):
        self.A_price = price

    def set_price_B(self, price):
        self.A_price = 1 / price

    def get_value_in_token_A(self):
        real_value = super().get_value_in_token_A()
        # discount initial liquidity for APR calculation
        return real_value - self.initial_A_liquidity

    def get_A_amount_for_liquidity(self, token_B_amount):
        return token_B_amount * self.get_token_B_price()

    def get_B_amount_for_liquidity(self, token_A_amount):
        return token_A_amount * self.get_token_A_price()

    def add_liquidity(self, account, token_A_amount, token_B_amount):
        assert token_A_amount > 0
        lp_amount = token_A_amount

        self.token_A.transfer(account, self.pool_account, token_A_amount)
        if token_B_amount > 0:
            self.token_B.transfer(account, self.pool_account, token_B_amount)
            lp_amount = lp_amount + token_B_amount * self.get_token_B_price()

        self.lp_token.mint(account, lp_amount)

        return

    def udpate_after_liquidity_movement(self):
        pass

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        return self.add_liquidity(account, token_A_amount, 0)

    def add_liquidity_single_B(self, account, token_B_amount, max_slippage):
        assert token_B_amount > 0
        total_liquidity = self.get_total_liquidity()

        lp_amount = token_B_amount * self.get_token_B_price()
        self.lp_token.mint(account, lp_amount)

        self.token_B.transfer(account, self.pool_account, token_B_amount)

        return

    def swap_A_for_B(self, account, input_amount):
        try:
            assert input_amount >= 0.0
        except:
            print(f"User:   {account}")
            print(f"amount: {input_amount:,.2f}")
            raise RuntimeError('Error, swapping negative amount!')

        if input_amount == 0.0:
            return 0.0
        # checked on transfer
        #assert self.token_A.balance_of(self.account) > amount
        output_amount = input_amount * self.get_token_A_price()
        #print(f"in:  {input_amount:,.2f}")
        #print(f"out: {output_amount:,.2f}")
        self.token_A.transfer(account, self.pool_account, input_amount)
        self.token_B.transfer(self.pool_account, account, output_amount)

        self.fees_accrued_A = self.fees_accrued_A + input_amount * self.fee

        return output_amount

    def swap_B_for_A(self, account, input_amount):
        try:
            assert input_amount >= 0.0
        except:
            print(f"User:   {account}")
            print(f"amount: {input_amount:,.2f}")
            raise RuntimeError('Error, swapping negative amount!')

        if input_amount == 0.0:
            return 0.0
        # checked on transfer
        #assert self.token_B.balance_of(self.account) > amount
        output_amount = input_amount * self.get_token_B_price()
        self.token_B.transfer(account, self.pool_account, input_amount)
        self.token_A.transfer(self.pool_account, account, output_amount)

        self.fees_accrued_B = self.fees_accrued_B + input_amount * self.fee

        return output_amount

    def get_output_amount(self, input_token_balance, output_token_balance, input_amount, D_offset=None):
        pass

    def get_input_amount(self, input_token, output_token, output_amount):
        pass

    def get_token_A_price(self):
        return self.A_price

    def get_token_B_price(self):
        return 1 / self.A_price

    # Given a target token A price, returns the amount of token B that needs to be swapped to increase
    # current token A price to the desired target
    def get_input_B_amount_from_target_price_A(self, target_price):
        pass

    # Given a target token B price, returns the amount of token A that needs to be swapped to increase
    # current token B price to the desired target
    def get_input_A_amount_from_target_price_B(self, target_price):
        pass

    def get_input_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        #return self.token_B_balance() * self.get_token_B_price()
        # token A balance is fake:
        effective_token_A_balance = self.token_B_balance() * self.get_token_B_price()
        return effective_token_A_balance() * (1/(math.sqrt(1 - slippage)) - 1)

    def get_input_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        #return self.token_A_balance() * self.get_token_A_price()
        return self.token_B_balance() * (1/(math.sqrt(1 - slippage)) - 1)

    # TODO
    def get_output_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return self.token_A_balance()

    # TODO
    def get_output_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return self.token_B_balance()
