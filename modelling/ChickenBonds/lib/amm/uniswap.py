import math
from lib.amm.amm_base import *

class UniswapPool(AmmBase):
    def sqrt_k(self):
        return math.sqrt(self.token_A_balance() * self.token_B_balance())

    def get_A_amount_for_liquidity(self, token_B_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        if token_B_reserve == 0:
            return token_B_amount
        return token_B_amount * token_A_reserve / token_B_reserve
    def get_B_amount_for_liquidity(self, token_A_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        if token_A_reserve == 0:
            return token_A_amount
        return token_A_amount * token_B_reserve / token_A_reserve
    def add_liquidity(self, account, token_A_amount, max_token_B_amount):
        total_liquidity = self.get_total_liquidity()
        if total_liquidity == 0: # initial liquidity
            #print(f"token_A_amount: {token_A_amount:,.2f}")
            assert token_A_amount > 0.1

            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, max_token_B_amount)

            self.lp_token.mint(account, token_A_amount)
        else:
            token_B_amount = self.get_B_amount_for_liquidity(token_A_amount)
            #print(f"token_B_amount:     {token_B_amount:,.2f}")
            #print(f"max_token_B_amount: {max_token_B_amount:,.2f}")
            #assert token_B_amount <= max_token_B_amount

            token_A_reserve = self.token_A_balance()
            liquidity_minted = token_A_amount * total_liquidity / token_A_reserve

            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, token_B_amount)

            self.lp_token.mint(account, liquidity_minted)
        return

    """
    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        # TODO: Max slippage
        token_A_reserve = self.token_A_balance()
        amount_to_add = token_A_reserve + token_A_amount - math.sqrt(token_A_reserve * (token_A_reserve + token_A_amount))
        amount_to_swap = token_A_amount - amount_to_add
        token_B_amount = self.swap_A_for_B(account, amount_to_swap)
        return self.add_liquidity(account, amount_to_add, token_B_amount)
    """

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        initial_value_in_A = self.get_value_in_token_A()
        assert initial_value_in_A > 0
        total_liquidity = self.get_total_liquidity()

        self.token_A.transfer(account, self.pool_account, token_A_amount)

        final_value_in_A = self.get_value_in_token_A()
        liquidity_minted = final_value_in_A * total_liquidity / initial_value_in_A

        self.lp_token.mint(account, liquidity_minted)
        return

    def add_liquidity_single_B(self, account, token_B_amount, max_slippage):
        initial_value_in_B = self.get_value_in_token_B()
        assert initial_value_in_B > 0
        total_liquidity = self.get_total_liquidity()

        self.token_B.transfer(account, self.pool_account, token_B_amount)

        final_value_in_B = self.get_value_in_token_B()
        liquidity_minted = final_value_in_B * total_liquidity / initial_value_in_B

        self.lp_token.mint(account, liquidity_minted)
        return

    def get_output_amount(self, input_token_balance, output_token_balance, input_amount, D=None):
        if input_amount == 0.0:
            return 0.0
        x = input_token_balance
        y = output_token_balance

        input_amount_with_fee = input_amount * (1 - self.fee)
        return y * input_amount_with_fee / (x + input_amount_with_fee)

    def get_input_amount(self, input_token, output_token, output_amount):
        if output_amount == 0.0:
            return 0.0, 0.0
        x = input_token.balance_of(self.pool_account)
        y = output_token.balance_of(self.pool_account)
        # only allow to withdraw up to 90%
        output_amount = min(output_amount, y * 0.9)

        return x * output_amount / (y - output_amount) / (1 - self.fee)

    def get_token_A_price(self):
        x = self.token_A_balance()
        y = self.token_B_balance()
        if x == 0:
            return 0
        return y / x

    def get_token_B_price(self):
        x = self.token_A_balance()
        y = self.token_B_balance()
        if y == 0:
            return 0
        return x / y

    # Given a target token A price, returns the amount of token B that needs to be swapped to increase
    # current token A price to the desired target
    def get_input_B_amount_from_target_price_A(self, target_price):
        input_amount = math.sqrt(self.token_A_balance() * self.token_B_balance() * target_price) - self.token_B_balance()
        return input_amount / (1 - self.fee)

    # Given a target token B price, returns the amount of token A that needs to be swapped to increase
    # current token B price to the desired target
    def get_input_A_amount_from_target_price_B(self, target_price):
        input_amount = math.sqrt(self.token_A_balance() * self.token_B_balance() * target_price) - self.token_A_balance()
        return input_amount / (1 - self.fee)

    def get_input_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        input_amount = (self.token_A_balance() + token_A_offset) * (1 / math.sqrt(1 - slippage) - 1)
        return input_amount / (1 - self.fee)

    def get_input_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        input_amount = (self.token_B_balance() + token_B_offset) * (1 / math.sqrt(1 - slippage) - 1)
        return input_amount / (1 - self.fee)

    def get_output_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return (self.token_A_balance() + token_A_offset) * (1 - math.sqrt(1 - slippage))

    def get_output_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return (self.token_B_balance() + token_B_offset) * (1 - math.sqrt(1 - slippage))

